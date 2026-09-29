import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/prayer_requests.dart';
import 'cloud_sync_service.dart';

/// Server round-trips for the anonymous shared-prayer-request wall. Like
/// [SocialService], every call is a safe no-op when the backend isn't
/// configured or the session is signed out — the screen just shows an offline
/// state. All the real rules (2/week cap, "not your own", auto-hide on reports)
/// live in the SECURITY DEFINER RPCs in supabase/prayer_requests.sql; the client
/// is never trusted to enforce them.
class PrayerRequestService {
  PrayerRequestService(this._ref);

  final Ref _ref;
  bool get online => _ref.read(cloudSyncProvider).isReady;
  SupabaseClient get _db => Supabase.instance.client;

  /// Requests you may still send this rolling week, or null if offline.
  Future<int?> allowance() async {
    if (!online) return null;
    try {
      final n = await _db.rpc('prayer_request_allowance');
      return (n as num?)?.toInt();
    } catch (e) {
      debugPrint('allowance() failed: $e');
      return null;
    }
  }

  /// Send a request. Returns null on success, or a short error to show
  /// (e.g. the weekly limit message from the server).
  Future<String?> submit(String body) async {
    if (!online) return 'Connect to send a prayer request';
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'Write something first';
    if (trimmed.length > kPrayerRequestMaxChars) {
      return 'Keep it under $kPrayerRequestMaxChars characters';
    }
    try {
      await _db.rpc('submit_prayer_request', params: {'p_body': trimmed});
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not send request';
    }
  }

  /// One random visible request that isn't yours and you haven't prayed for yet.
  /// Null when offline or the pool is empty.
  Future<SharedPrayerRequest?> fetchRandom() async {
    if (!online) return null;
    try {
      final rows = await _db.rpc('random_prayer_request');
      final list = rows as List;
      if (list.isEmpty) return null;
      return SharedPrayerRequest.fromMap(
          (list.first as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('fetchRandom() failed: $e');
      return null;
    }
  }

  /// Record that you prayed for a request (idempotent server-side). Returns the
  /// new pray count, or null if it couldn't be recorded.
  Future<int?> pray(String requestId) async {
    if (!online) return null;
    try {
      final n = await _db
          .rpc('pray_for_request', params: {'p_request_id': requestId});
      return (n as num?)?.toInt();
    } on PostgrestException catch (e) {
      debugPrint('pray() failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('pray() failed: $e');
      return null;
    }
  }

  /// Total prayers across all of the caller's own requests — the signal behind
  /// the "someone prayed for you" notification. Null offline.
  Future<int?> myPrayTotal() async {
    if (!online) return null;
    try {
      final n = await _db.rpc('my_requests_pray_total');
      return (n as num?)?.toInt();
    } catch (e) {
      debugPrint('myPrayTotal() failed: $e');
      return null;
    }
  }

  /// Flag a request as inappropriate. Enough distinct reports auto-hides it.
  Future<void> report(String requestId) async {
    if (!online) return;
    try {
      await _db
          .rpc('report_prayer_request', params: {'p_request_id': requestId});
    } catch (e) {
      debugPrint('report() failed: $e');
    }
  }
}

final prayerRequestServiceProvider =
    Provider<PrayerRequestService>((ref) => PrayerRequestService(ref));
