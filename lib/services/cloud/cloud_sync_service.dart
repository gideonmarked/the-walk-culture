import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// The backend seam. Every method is a no-op / null when the app was built
/// without Supabase credentials, so the game stays fully playable offline and
/// the test suite never touches the network.
///
/// Split of authority today:
///   * VIP entitlement  — SERVER authoritative. Read from `entitlement`, which
///     is written only by the validate-purchase Edge Function. The client can
///     never grant itself VIP.
///   * Player progress  — cloud BACKUP (`profile.save_blob`) for reinstall /
///     new-device restore. Client-authored, so not yet anti-cheat; the
///     `credit_steps` RPC is already in the schema for when the wallet moves
///     server-side.
class CloudSyncService {
  CloudSyncService(this._ref);

  // ignore: unused_field — used once the wallet migrates to server RPCs.
  final Ref _ref;

  static bool _initialised = false;

  /// Boot Supabase and take an anonymous session. Anonymous auth is the right
  /// default for a game: cross-device restore with zero sign-up friction, and
  /// the account can be upgraded to email/Google later without losing the row.
  /// Safe to call unconditionally — returns immediately when unconfigured.
  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured || _initialised) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // Supabase renamed the "anon public" key to the publishable key; it's
        // the same value from Settings → API.
        publishableKey: SupabaseConfig.anonKey,
      );
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }
      _initialised = true;
    } catch (e) {
      // Never let a backend hiccup block launch — fall back to local-only.
      debugPrint('Supabase init failed, running local-only: $e');
    }
  }

  bool get isReady =>
      _initialised && Supabase.instance.client.auth.currentUser != null;

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  /// Server-authoritative VIP expiry. Null when unconfigured, signed out, or
  /// the player has never subscribed.
  Future<DateTime?> fetchVipUntil() async {
    if (!isReady) return null;
    try {
      final row = await _db
          .from('entitlement')
          .select('vip_until')
          .eq('user_id', _uid!)
          .maybeSingle();
      final raw = row?['vip_until'] as String?;
      return raw == null ? null : DateTime.parse(raw).toLocal();
    } catch (e) {
      debugPrint('fetchVipUntil failed: $e');
      return null;
    }
  }

  /// Hand a validated store purchase to the backend. The Edge Function verifies
  /// the receipt with Google and grants the entitlement; we never grant locally.
  /// Returns true when the server confirms the grant.
  Future<bool> validatePurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    if (!isReady) return false;
    try {
      final res = await _db.functions.invoke('validate-purchase', body: {
        'productId': productId,
        'purchaseToken': purchaseToken,
      });
      return (res.data as Map?)?['ok'] == true;
    } catch (e) {
      debugPrint('validatePurchase failed: $e');
      return false;
    }
  }

  /// Claim a rewarded-ad payout. The daily cap is enforced server-side, so a
  /// tampered client can't farm rewards. Returns the new lifetime total, or
  /// null if the cap was hit / the call failed.
  Future<int?> claimAdReward({int rewardSteps = 2000}) async {
    if (!isReady) return null;
    try {
      final res =
          await _db.rpc('claim_ad_reward', params: {'p_reward_steps': rewardSteps});
      return (res as num?)?.toInt();
    } catch (e) {
      debugPrint('claimAdReward failed: $e');
      return null;
    }
  }

  /// Upload the player's save. Fire-and-forget: a failed backup must never
  /// break play.
  Future<void> pushSave(Map<String, dynamic> saveJson) async {
    if (!isReady) return;
    try {
      await _db.from('profile').upsert({
        'user_id': _uid,
        'save_blob': saveJson,
        'health_level': saveJson['healthLevel'],
        'streak_current': saveJson['streakCurrent'],
        'streak_best': saveJson['streakBest'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('pushSave failed: $e');
    }
  }

  /// Download the cloud save, or null when there isn't one.
  Future<Map<String, dynamic>?> pullSave() async {
    if (!isReady) return null;
    try {
      final row = await _db
          .from('profile')
          .select('save_blob')
          .eq('user_id', _uid!)
          .maybeSingle();
      return (row?['save_blob'] as Map?)?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('pullSave failed: $e');
      return null;
    }
  }
}

final cloudSyncProvider =
    Provider<CloudSyncService>((ref) => CloudSyncService(ref));
