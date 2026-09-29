import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_info.dart';
import '../../core/feedback.dart';
import 'cloud_sync_service.dart';

/// Ships a [FeedbackReport] to the backend. Like every other cloud service
/// here, a no-op when Supabase isn't configured or the session is signed out —
/// the caller keeps the report queued and tries again later.
///
/// The rules (length cap, daily limit, dedupe on the client id) live in the
/// SECURITY DEFINER RPC in supabase/feedback.sql; the client isn't trusted with
/// any of them.
class FeedbackService {
  FeedbackService(this._ref);

  final Ref _ref;

  bool get online => _ref.read(cloudSyncProvider).isReady;
  SupabaseClient get _db => Supabase.instance.client;

  /// Send one report. Returns null on success, or a short reason to keep on the
  /// report so the history can explain why it hasn't gone out yet.
  ///
  /// Sending the same report twice is safe: the RPC dedupes on
  /// `(author, client_id)`, so a retry after a timeout that actually landed
  /// won't file a duplicate.
  Future<String?> send(FeedbackReport report) async {
    if (!online) return 'Waiting for a connection';
    try {
      await _db.rpc('submit_feedback', params: {
        'p_client_id': report.id,
        'p_kind': report.kind.wire,
        'p_body': report.body,
        'p_contact': report.contact.isEmpty ? null : report.contact,
        'p_diagnostics': report.diagnostics,
        'p_app_version': kAppVersion,
      });
      return null;
    } on PostgrestException catch (e) {
      debugPrint('submit_feedback failed: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('submit_feedback failed: $e');
      return 'Could not send yet';
    }
  }
}

final feedbackServiceProvider =
    Provider<FeedbackService>((ref) => FeedbackService(ref));
