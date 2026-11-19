import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/app_providers.dart' show HealthSyncController, OnboardingController;
import 'cloud_sync_service.dart';
import 'supabase_config.dart';

/// A login a player can attach to their anonymous account.
enum SignInProvider {
  google('Google'),
  apple('Apple');

  const SignInProvider(this.label);
  final String label;

  OAuthProvider get supabase =>
      this == SignInProvider.google ? OAuthProvider.google : OAuthProvider.apple;
}

/// What happened when the player tried to link a login.
enum LinkOutcome {
  /// The login is now attached to this phone's account. Nothing else changed.
  linked,

  /// That login already belongs to another player (e.g. they played on another
  /// phone). Call [AccountLinkService.switchToExisting] after asking.
  belongsToAnotherAccount,

  /// The player closed the sign-in sheet.
  cancelled,

  /// Something went wrong; [LinkResult.message] says what.
  failed,
}

/// A provider's proof of identity: what Supabase verifies.
class ProviderCredential {
  const ProviderCredential(this.provider, this.idToken, {this.rawNonce});
  final SignInProvider provider;
  final String idToken;

  /// Apple only: the unhashed nonce whose SHA-256 is inside [idToken].
  final String? rawNonce;
}

class LinkResult {
  const LinkResult(this.outcome, {this.message, this.credential});
  final LinkOutcome outcome;
  final String? message;

  /// Kept so a switch doesn't show the sign-in sheet twice.
  final ProviderCredential? credential;
}

/// Optional sign-in on top of the anonymous account.
///
/// Every player starts anonymous (no friction). Linking attaches a Google or
/// Apple identity to that SAME Supabase user, so all progress stays where it is
/// and can later be recovered on another phone by signing in again.
///
/// Platforms:
///   * Android — Google, when built with GOOGLE_WEB_CLIENT_ID.
///   * iOS     — Sign in with Apple always (App Review guideline 4.8 requires
///               it whenever another social login is offered), plus Google
///               when built with GOOGLE_IOS_CLIENT_ID too.
///
/// Supabase setup (docs/DEPLOY.md): the Google/Apple providers enabled with
/// their client IDs, and **manual linking** turned on.
class AccountLinkService {
  AccountLinkService(this._ref);

  final Ref _ref;
  static bool _googleReady = false;

  SupabaseClient get _db => Supabase.instance.client;

  bool get _hasBackend => _ref.read(cloudSyncProvider).isConfigured;

  /// Logins offered on this device, in display order.
  List<SignInProvider> get availableProviders {
    if (!_hasBackend) return const [];
    final hasGoogleWeb = SupabaseConfig.googleWebClientId.isNotEmpty;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => [
          SignInProvider.apple,
          if (hasGoogleWeb && SupabaseConfig.googleIosClientId.isNotEmpty)
            SignInProvider.google,
        ],
      TargetPlatform.android => [if (hasGoogleWeb) SignInProvider.google],
      _ => const [],
    };
  }

  bool get available => availableProviders.isNotEmpty;

  User? get _user =>
      _ref.read(cloudSyncProvider).isReady ? _db.auth.currentUser : null;

  /// How the linked account is shown ("you@gmail.com"), or null while the
  /// account is still anonymous.
  String? get linkedLabel {
    final u = _user;
    if (u == null || u.isAnonymous) return null;
    final email = u.email;
    if (email != null && email.isNotEmpty) return email;
    final provider = u.appMetadata['provider'] as String?;
    return provider == 'apple' ? 'your Apple ID' : 'your Google account';
  }

  Future<ProviderCredential> _credential(SignInProvider provider) async {
    switch (provider) {
      case SignInProvider.google:
        final google = GoogleSignIn.instance;
        if (!_googleReady) {
          await google.initialize(
            clientId: defaultTargetPlatform == TargetPlatform.iOS
                ? SupabaseConfig.googleIosClientId
                : null,
            serverClientId: SupabaseConfig.googleWebClientId,
          );
          _googleReady = true;
        }
        final account = await google.authenticate(scopeHint: const ['email']);
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw const AuthException('Google returned no ID token');
        }
        return ProviderCredential(provider, idToken);

      case SignInProvider.apple:
        // Apple puts SHA-256(nonce) in the token; Supabase gets the raw value
        // and checks they match, so a stolen token can't be replayed.
        final rawNonce = _randomNonce();
        final apple = await SignInWithApple.getAppleIDCredential(
          scopes: const [AppleIDAuthorizationScopes.email],
          nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
        );
        final idToken = apple.identityToken;
        if (idToken == null) {
          throw const AuthException('Apple returned no identity token');
        }
        return ProviderCredential(provider, idToken, rawNonce: rawNonce);
    }
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static bool _wasCancelled(Object e) =>
      (e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) ||
      (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled);

  /// Attach [provider]'s login to this phone's account.
  Future<LinkResult> link(SignInProvider provider) async {
    if (!availableProviders.contains(provider)) {
      return LinkResult(LinkOutcome.failed,
          message: '${provider.label} sign-in isn’t set up in this build');
    }
    if (_user == null) {
      return const LinkResult(LinkOutcome.failed,
          message: 'Connect to the internet to link your account');
    }

    final ProviderCredential cred;
    try {
      cred = await _credential(provider);
    } catch (e) {
      if (_wasCancelled(e)) return const LinkResult(LinkOutcome.cancelled);
      debugPrint('${provider.label} sign-in failed: $e');
      return LinkResult(LinkOutcome.failed,
          message: '${provider.label} sign-in failed — please try again');
    }

    try {
      await _db.auth.linkIdentityWithIdToken(
          provider: provider.supabase,
          idToken: cred.idToken,
          nonce: cred.rawNonce);
      return const LinkResult(LinkOutcome.linked);
    } on AuthException catch (e) {
      if (e.code == ErrorCode.identityAlreadyExists.code ||
          e.message.toLowerCase().contains('already')) {
        return LinkResult(LinkOutcome.belongsToAnotherAccount, credential: cred);
      }
      debugPrint('linkIdentityWithIdToken failed: ${e.code} ${e.message}');
      return LinkResult(LinkOutcome.failed, message: e.message);
    } catch (e) {
      debugPrint('linkIdentityWithIdToken failed: $e');
      return const LinkResult(LinkOutcome.failed,
          message: 'Could not link your account — please try again');
    }
  }

  /// Move this phone onto the account that already owns [cred]'s login.
  ///
  /// The anonymous account on this phone is deleted (the player was warned its
  /// progress is replaced), local data is cleared except onboarding and the
  /// health-sync setting, and the caller rebuilds state — which pulls the
  /// other account's cloud save down. Returns null on success.
  Future<String?> switchToExisting(ProviderCredential cred) async {
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
          provider: cred.provider.supabase,
          idToken: cred.idToken,
          nonce: cred.rawNonce);
    } catch (e) {
      debugPrint('signInWithIdToken failed: $e');
      await _recoverAnonymousSession();
      return 'Could not sign in with ${cred.provider.label} — please try again';
    }
    await clearLocalProgress();
    return null;
  }

  /// Sign out. The progress stays in the linked account; this phone starts
  /// fresh on a new anonymous account.
  Future<String?> signOut() async {
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
      if (_googleReady) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
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

final accountLinkServiceProvider =
    Provider<AccountLinkService>((ref) => AccountLinkService(ref));
