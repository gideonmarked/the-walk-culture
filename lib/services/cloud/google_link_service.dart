import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/app_providers.dart' show HealthSyncController, OnboardingController;
import 'cloud_sync_service.dart';
import 'supabase_config.dart';

/// What happened when the player tried to link Google.
enum LinkOutcome {
  /// Google is now attached to this phone's account. Nothing else changed.
  linked,

  /// That Google account already belongs to another player (e.g. they played
  /// on another phone). Call [GoogleLinkService.switchToExisting] to move this
  /// phone onto it, after asking.
  belongsToAnotherAccount,

  /// The player closed the Google picker.
  cancelled,

  /// Something went wrong; [LinkResult.message] says what.
  failed,
}

class LinkResult {
  const LinkResult(this.outcome, {this.message, this.idToken});
  final LinkOutcome outcome;
  final String? message;

  /// Kept from the attempt so a switch doesn't show the Google picker twice.
  final String? idToken;
}

/// Optional Google sign-in on top of the anonymous account.
///
/// Every player starts anonymous (no friction). Linking attaches a Google
/// identity to that SAME Supabase user, so all progress stays where it is and
/// can later be recovered on another phone by signing in with Google.
///
/// Supabase setup needed (see docs/DEPLOY.md): the Google provider enabled with
/// the Web and Android client IDs, and **manual linking** turned on.
class GoogleLinkService {
  GoogleLinkService(this._ref);

  final Ref _ref;
  static bool _googleReady = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// Only offered on Android builds that have a backend and a Google client ID.
  /// (On iOS, Apple requires Sign in with Apple alongside Google.)
  bool get available =>
      defaultTargetPlatform == TargetPlatform.android &&
      SupabaseConfig.googleWebClientId.isNotEmpty &&
      _ref.read(cloudSyncProvider).isConfigured;

  User? get _user =>
      _ref.read(cloudSyncProvider).isReady ? _db.auth.currentUser : null;

  /// The linked Google email, or null while the account is still anonymous.
  String? get linkedEmail {
    final u = _user;
    if (u == null || u.isAnonymous) return null;
    return u.email ?? 'your Google account';
  }

  Future<String> _googleIdToken() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: SupabaseConfig.googleWebClientId);
      _googleReady = true;
    }
    final account = await google.authenticate(scopeHint: const ['email']);
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException('Google returned no ID token');
    return idToken;
  }

  /// Attach Google to this phone's account.
  Future<LinkResult> link() async {
    if (!available) {
      return const LinkResult(LinkOutcome.failed,
          message: 'Google sign-in isn’t set up in this build');
    }
    if (_user == null) {
      return const LinkResult(LinkOutcome.failed,
          message: 'Connect to the internet to link your account');
    }

    final String idToken;
    try {
      idToken = await _googleIdToken();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const LinkResult(LinkOutcome.cancelled);
      }
      debugPrint('Google sign-in failed: $e');
      return const LinkResult(LinkOutcome.failed,
          message: 'Google sign-in failed — please try again');
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return const LinkResult(LinkOutcome.failed,
          message: 'Google sign-in failed — please try again');
    }

    try {
      await _db.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google, idToken: idToken);
      return const LinkResult(LinkOutcome.linked);
    } on AuthException catch (e) {
      if (e.code == ErrorCode.identityAlreadyExists.code ||
          e.message.toLowerCase().contains('already')) {
        return LinkResult(LinkOutcome.belongsToAnotherAccount, idToken: idToken);
      }
      debugPrint('linkIdentityWithIdToken failed: ${e.code} ${e.message}');
      return LinkResult(LinkOutcome.failed, message: e.message);
    } catch (e) {
      debugPrint('linkIdentityWithIdToken failed: $e');
      return const LinkResult(LinkOutcome.failed,
          message: 'Could not link your account — please try again');
    }
  }

  /// Move this phone onto the Google account that already has progress.
  ///
  /// The anonymous account on this phone is deleted (the player was warned its
  /// progress is replaced), local data is cleared except onboarding and the
  /// health-sync setting, and the caller rebuilds state — which pulls the
  /// Google account's cloud save down. Returns null on success.
  Future<String?> switchToExisting(String idToken) async {
    final wasAnonymous = _user?.isAnonymous ?? false;
    if (wasAnonymous) {
      try {
        await _db.rpc('delete_my_account');
      } catch (e) {
        // Not fatal: an orphaned anonymous account holds no personal data.
        debugPrint('could not delete the anonymous account: $e');
      }
    }
    try {
      await _db.auth.signInWithIdToken(
          provider: OAuthProvider.google, idToken: idToken);
    } on AuthException catch (e) {
      debugPrint('signInWithIdToken failed: ${e.message}');
      await _recoverAnonymousSession();
      return 'Could not sign in with Google — please try again';
    } catch (e) {
      debugPrint('signInWithIdToken failed: $e');
      await _recoverAnonymousSession();
      return 'Could not sign in with Google — please try again';
    }
    await clearLocalProgress();
    return null;
  }

  /// Sign out of Google. The progress stays in the Google account; this phone
  /// starts fresh on a new anonymous account.
  Future<String?> signOut() async {
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      await _db.auth.signInAnonymously();
    } catch (e) {
      debugPrint('signOut failed: $e');
      return 'Could not sign out — please try again';
    }
    await clearLocalProgress();
    return null;
  }

  Future<void> _recoverAnonymousSession() async {
    if (_db.auth.currentSession != null) return;
    try {
      await _db.auth.signInAnonymously();
    } catch (_) {}
  }

  /// Clear everything but the two settings that aren't progress, so the player
  /// isn't sent back through onboarding.
  @visibleForTesting
  static Future<void> clearLocalProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(OnboardingController.prefsKey);
    final healthSync = prefs.getBool(HealthSyncController.prefsKey);
    await prefs.clear();
    if (onboarded != null) {
      await prefs.setBool(OnboardingController.prefsKey, onboarded);
    }
    if (healthSync != null) {
      await prefs.setBool(HealthSyncController.prefsKey, healthSync);
    }
  }
}

final googleLinkServiceProvider =
    Provider<GoogleLinkService>((ref) => GoogleLinkService(ref));
