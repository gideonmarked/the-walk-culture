import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_sync_service.dart';

/// Account deletion — Google Play's User Data policy requires an in-app way to
/// delete the account AND its data.
///
/// The server side is `delete_my_account()` in supabase/safety.sql, which
/// deletes the auth user; every table keyed on it cascades. Local data
/// (SharedPreferences: progress, journal, inbox, settings) is wiped too, so the
/// phone holds nothing from the old account afterwards.
class AccountService {
  AccountService(this._ref);

  final Ref _ref;

  /// Delete the account. Returns null on success or a short error to show.
  ///
  /// Order matters: the server delete runs FIRST, so a failure there leaves
  /// everything intact rather than wiping the phone while the cloud copy lives
  /// on (and would be restored on next launch).
  Future<String?> deleteAccount() async {
    final cloud = _ref.read(cloudSyncProvider);
    if (cloud.isConfigured) {
      if (!cloud.isReady) {
        return 'Connect to the internet to delete your account';
      }
      try {
        await Supabase.instance.client.rpc('delete_my_account');
      } on PostgrestException catch (e) {
        debugPrint('delete_my_account failed: ${e.message}');
        return 'Could not delete your account — please try again';
      } catch (e) {
        debugPrint('delete_my_account failed: $e');
        return 'Could not delete your account — please try again';
      }
      try {
        // The user no longer exists server-side; drop the dead session.
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        debugPrint('signOut after delete failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (cloud.isConfigured) {
      // Start over with a brand-new anonymous account, so the app keeps working
      // without a restart. It shares nothing with the deleted one.
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        debugPrint('fresh anonymous sign-in failed: $e');
      }
    }
    return null;
  }
}

final accountServiceProvider =
    Provider<AccountService>((ref) => AccountService(ref));
