import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import '../core/feedback.dart';
import '../core/health.dart';
import '../core/travel_pass.dart';
import '../services/cloud/cloud_sync_service.dart';
import '../services/cloud/feedback_service.dart';
import 'app_providers.dart';
import 'premium_providers.dart';

/// The feedback outbox — newest first.
///
/// Stored in its own prefs key, never in the synced player blob: it's the
/// player's words, and it goes exactly one place (the backend, on submit) and
/// nowhere else.
final feedbackControllerProvider =
    StateNotifierProvider<FeedbackController, List<FeedbackReport>>(
        (ref) => FeedbackController(ref));

class FeedbackController extends StateNotifier<List<FeedbackReport>> {
  FeedbackController(this._ref) : super(const []) {
    _ready = _load();
  }

  final Ref _ref;
  static const _key = 'twc_feedback_v1';

  /// Completes once the saved outbox is in memory. Every write waits on this:
  /// a submit that raced the load would otherwise save a one-item list over
  /// the player's stored history and lose it for good.
  late final Future<void> _ready;

  /// Keep the newest few DELIVERED reports. This is a local receipt for the
  /// player, not an archive — the server has the real copy once it's sent.
  static const _cap = 30;

  /// Absolute ceiling, pending included. Only reachable by someone filing
  /// dozens of reports with no connection at all.
  static const _hardCap = 100;

  final Random _rng = Random();
  bool _flushing = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = (jsonDecode(raw) as List)
            .map((e) =>
                FeedbackReport.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } catch (e) {
        debugPrint('Failed to load feedback outbox: $e');
      }
    }
    // Retry anything queued on a previous run. Deliberately NOT awaited: it
    // talks to the network, and it must not hold up the player's first submit
    // (which waits on [_ready]).
    unawaited(flushPending());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final r in state) r.toJson()]));
  }

  /// The build/progress context attached to a new report. Exposed so the form
  /// can show the player exactly what they're about to send — this app asks
  /// before it takes health data, and it shouldn't be sloppier about telemetry.
  ///
  /// Deliberately excludes anything private: no gratitude or prayer text, no
  /// account code, no contact details the player didn't type.
  Map<String, String> get currentDiagnostics {
    final player = _ref.read(playerControllerProvider);
    final premium = _ref.read(premiumControllerProvider);
    final passLevel = passLevelForXp(player.passXp);
    return {
      'App version': kAppVersion,
      'Platform': defaultTargetPlatform.name,
      'OS': _osVersion,
      'Health level': healthLevelInfo(player.healthLevel).name,
      'Lifetime Pebbles': '${player.lifetimeSteps}',
      'Steps today': '${player.todaySteps}',
      'Streak': '${player.streakCurrent} days',
      'Travel Pass': 'level $passLevel of $kPassLevelCount',
      'VIP': premium.isVip ? 'active' : 'no',
      'Health sync': _ref.read(healthSyncProvider) ? 'on' : 'off',
      'Backend': _ref.read(cloudSyncProvider).isReady ? 'connected' : 'offline',
    };
  }

  String get _osVersion {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown'; // no dart:io (web); never worth failing a report over
    }
  }

  /// Queue a report and try to send it immediately.
  ///
  /// Returns null once the report is safely stored — which is the promise the
  /// UI makes — or a validation message if there was nothing worth storing.
  /// A failed SEND is not a failed submit: the report stays queued and retries.
  Future<String?> submit({
    required FeedbackKind kind,
    required String body,
    String contact = '',
  }) async {
    final problem = validateFeedbackBody(body);
    if (problem != null) return problem;
    await _ready; // never write over a load that hasn't landed

    final report = FeedbackReport(
      // Timestamp plus a random tail: unique locally, and the key the server
      // dedupes retries on.
      id: '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32)}',
      kind: kind,
      body: body.trim(),
      contact: contact.trim(),
      diagnostics: currentDiagnostics,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    state = _trim([report, ...state]);
    await _save();
    await flushPending();
    return null;
  }


  /// Trim without ever evicting something still unsent.
  ///
  /// A plain `take(_cap)` drops the oldest report even when it has never been
  /// delivered — which is precisely the case this outbox exists to protect. So
  /// pending reports are kept past the cap, and only DELIVERED ones are
  /// discarded to make room. [_hardCap] is the backstop: past it we do start
  /// dropping the oldest pending, because unbounded growth on disk is its own
  /// bug.
  List<FeedbackReport> _trim(List<FeedbackReport> all) {
    if (all.length <= _cap) return all;
    var sentBudget = _cap - all.where((r) => r.isPending).length;
    final kept = <FeedbackReport>[];
    for (final report in all) {
      // `all` is newest-first, so this keeps the most recent of each kind.
      if (report.isPending) {
        kept.add(report);
      } else if (sentBudget > 0) {
        kept.add(report);
        sentBudget--;
      }
    }
    return kept.length <= _hardCap ? kept : kept.take(_hardCap).toList();
  }

  /// How many reports are still waiting to go out.
  int get pendingCount => state.where((r) => r.isPending).length;

  /// Retry every queued report. Safe to call often — a no-op when there's
  /// nothing pending, and the RPC is idempotent per report id, so a report
  /// that actually landed before a timeout won't be filed twice.
  /// Never throws — it's kicked off unawaited from [_load] and [submit], so an
  /// escaping error would become an unhandled async error (and a crash report).
  Future<void> flushPending() async {
    if (_flushing || !mounted) return;
    final pending = state.where((r) => r.isPending).toList();
    if (pending.isEmpty) return;

    _flushing = true;
    try {
      final service = _ref.read(feedbackServiceProvider);
      var changed = false;
      for (final report in pending) {
        final error = await service.send(report);
        // The app can be torn down mid-flush — stop rather than touch a
        // disposed container.
        if (!mounted) return;
        // Re-find by id: `state` may have been replaced while we awaited.
        final i = state.indexWhere((r) => r.id == report.id);
        if (i < 0) continue;
        final next = [...state];
        next[i] = error == null
            ? state[i].copyWith(status: FeedbackStatus.sent, lastError: '')
            : state[i].copyWith(lastError: error);
        state = next;
        changed = true;
      }
      if (changed && mounted) await _save();
    } catch (e) {
      debugPrint('feedback flush failed (ignored): $e');
    } finally {
      _flushing = false;
    }
  }

  /// Dev tool: empty the local receipt list. Doesn't touch anything already
  /// delivered to the server.
  Future<void> clear() async {
    await _ready;
    state = const [];
    await _save();
  }
}

/// Queued-but-unsent count, for a badge on the feedback entry point.
final pendingFeedbackCountProvider = Provider<int>((ref) =>
    ref.watch(feedbackControllerProvider).where((r) => r.isPending).length);
