import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_info.dart';
import '../../core/crash.dart';
import 'cloud_sync_service.dart';

/// Ships a [CrashReport] to the backend. A no-op when Supabase isn't
/// configured or signed out — the caller keeps it queued.
class CrashService {
  CrashService(this._ref);

  final Ref _ref;

  bool get online => _ref.read(cloudSyncProvider).isReady;
  SupabaseClient get _db => Supabase.instance.client;

  /// Send one report. Returns true when the server took it.
  ///
  /// Idempotent per `(author, client_id)`: a retry after a timeout won't file a
  /// duplicate, and re-sending a recurring crash UPDATES its occurrence count
  /// rather than adding a row — so "this happened 400 times" arrives as one
  /// report with a number on it.
  Future<bool> send(CrashReport report) async {
    if (!online) return false;
    try {
      await _db.rpc('submit_crash', params: {
        'p_client_id': report.id,
        'p_fingerprint': report.fingerprint,
        'p_kind': report.kind.name,
        'p_message': report.message,
        'p_stack': report.stack,
        'p_library': report.library.isEmpty ? null : report.library,
        'p_occurrences': report.occurrences,
        'p_first_seen': DateTime.fromMillisecondsSinceEpoch(report.firstSeenMs)
            .toUtc()
            .toIso8601String(),
        'p_last_seen': DateTime.fromMillisecondsSinceEpoch(report.lastSeenMs)
            .toUtc()
            .toIso8601String(),
        'p_diagnostics': report.diagnostics,
        'p_app_version': kAppVersion,
      });
      return true;
    } on PostgrestException catch (e) {
      debugPrint('submit_crash failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('submit_crash failed: $e');
      return false;
    }
  }
}

final crashServiceProvider = Provider<CrashService>((ref) => CrashService(ref));
