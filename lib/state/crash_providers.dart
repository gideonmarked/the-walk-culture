import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/crash.dart';
import '../services/cloud/crash_service.dart';
import 'feedback_providers.dart';

/// The crash outbox plus the player's opt-out. One state object so Settings can
/// watch a single provider and see both.
@immutable
class CrashOutbox {
  const CrashOutbox({this.reports = const [], this.enabled = true});

  /// Newest first.
  final List<CrashReport> reports;

  /// Whether errors are recorded and sent at all. Default on — a beta with
  /// crash reporting switched off is just guesswork — but the player can turn
  /// it off in Settings, and Play's Data Safety form must declare "Crash logs"
  /// either way.
  final bool enabled;

  int get pendingCount => reports.where((r) => r.isPending).length;

  CrashOutbox copyWith({List<CrashReport>? reports, bool? enabled}) =>
      CrashOutbox(
        reports: reports ?? this.reports,
        enabled: enabled ?? this.enabled,
      );
}

final crashControllerProvider =
    StateNotifierProvider<CrashController, CrashOutbox>(
        (ref) => CrashController(ref));

class CrashController extends StateNotifier<CrashOutbox> {
  CrashController(this._ref) : super(const CrashOutbox()) {
    _ready = _load();
  }

  final Ref _ref;
  static const _key = 'twc_crashes_v1';
  static const _enabledKey = 'twc_crash_reporting_v1';

  /// Distinct DELIVERED bugs kept on the device. Small on purpose: the
  /// interesting ones are the newest, and the server has the rest once sent.
  static const _cap = 20;

  /// Absolute ceiling, pending included. Repeats already collapse by
  /// fingerprint, so reaching this means genuinely dozens of distinct bugs.
  static const _hardCap = 100;

  /// Completes once the saved outbox is in memory. Writes wait on it so a crash
  /// during startup can't save a one-item list over the stored history.
  late final Future<void> _ready;

  final Random _rng = Random();
  Timer? _saveDebounce;
  bool _recording = false;
  bool _flushing = false;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(enabled: prefs.getBool(_enabledKey) ?? true);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = state.copyWith(
          reports: (jsonDecode(raw) as List)
              .map((e) =>
                  CrashReport.fromJson((e as Map).cast<String, dynamic>()))
              .toList(),
        );
      } catch (e) {
        debugPrint('Failed to load crash outbox: $e');
      }
    }
    // Ship whatever the last run couldn't. Not awaited — it's network work and
    // must not gate a record() that happens moments later.
    unawaited(flushPending());
  }

  Future<void> _save() async {
    _saveDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final r in state.reports) r.toJson()]));
  }

  /// Repeats of a known bug only bump a counter, so persisting each one would
  /// mean a disk write per frame. Coalesce those; a first sighting still saves
  /// straight away, because that's the one that might not survive the crash.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () => _save());
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Record an error. Never throws and never rethrows — a crash reporter that
  /// crashes is worse than none — and is safe to call from an error handler.
  Future<void> record({
    required Object error,
    StackTrace? stack,
    CrashKind kind = CrashKind.async,
    String library = '',
  }) async {
    // Guard against an error raised by this method itself looping forever.
    if (_recording) return;
    _recording = true;
    try {
      await _ready;
      if (!state.enabled) return;

      final message = summarizeCrashMessage(error);
      final trimmed = trimStack(stack?.toString());
      final fingerprint =
          crashFingerprint(message: message, stack: trimmed);
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing =
          state.reports.indexWhere((r) => r.fingerprint == fingerprint);
      if (existing >= 0) {
        // Same bug again: one report, a bigger number on it.
        final next = [...state.reports];
        next[existing] = next[existing].recur(atMs: now);
        state = state.copyWith(reports: next);
        _scheduleSave();
        return;
      }

      final report = CrashReport(
        id: '$now-${_rng.nextInt(1 << 32)}',
        fingerprint: fingerprint,
        kind: kind,
        message: message,
        stack: trimmed,
        library: library,
        firstSeenMs: now,
        lastSeenMs: now,
        diagnostics: _diagnostics(),
      );
      state = state.copyWith(reports: _trim([report, ...state.reports]));
      await _save(); // a new bug is worth a write right now
      unawaited(flushPending());
    } catch (e) {
      debugPrint('crash recorder failed (ignored): $e');
    } finally {
      _recording = false;
    }
  }


  /// Trim without ever evicting something still unsent.
  ///
  /// A plain `take(_cap)` drops the oldest report even when it has never been
  /// delivered — which is precisely the case this outbox exists to protect. So
  /// pending reports are kept past the cap, and only DELIVERED ones are
  /// discarded to make room. [_hardCap] is the backstop: past it we do start
  /// dropping the oldest pending, because unbounded growth on disk is its own
  /// bug.
  List<CrashReport> _trim(List<CrashReport> all) {
    if (all.length <= _cap) return all;
    var sentBudget = _cap - all.where((r) => r.isPending).length;
    final kept = <CrashReport>[];
    for (final report in all) {
      if (report.isPending) {
        kept.add(report);
      } else if (sentBudget > 0) {
        kept.add(report);
        sentBudget--;
      }
    }
    return kept.length <= _hardCap ? kept : kept.take(_hardCap).toList();
  }

  /// Reuse the feedback form's context builder so a crash and a bug report
  /// carry exactly the same fields — and so there's one place to audit for
  /// anything that shouldn't be leaving the device.
  Map<String, String> _diagnostics() {
    try {
      return _ref.read(feedbackControllerProvider.notifier).currentDiagnostics;
    } catch (e) {
      // Diagnostics are a nice-to-have; never lose the crash over them.
      return const {};
    }
  }

  /// Try to deliver everything queued. Safe to call often.
  ///
  /// NEVER throws. It's kicked off unawaited from [record] and [_load], so an
  /// escaping error would surface as an unhandled async error — which this
  /// very class is hooked up to record, and a crash reporter that feeds itself
  /// is a loop worth designing out.
  Future<void> flushPending() async {
    if (_flushing || !mounted) return;
    if (!state.enabled) return;
    final pending = state.reports.where((r) => r.isPending).toList();
    if (pending.isEmpty) return;

    _flushing = true;
    try {
      final service = _ref.read(crashServiceProvider);
      var changed = false;
      for (final report in pending) {
        final ok = await service.send(report);
        // The app can be torn down mid-flush — stop rather than touch a
        // disposed container.
        if (!mounted) return;
        if (!ok) continue;
        // Re-find by id: state may have moved on while we awaited, and the
        // occurrence count may have grown. Only mark sent if it hasn't.
        final i = state.reports.indexWhere((r) => r.id == report.id);
        if (i < 0) continue;
        if (state.reports[i].occurrences != report.occurrences) continue;
        final next = [...state.reports];
        next[i] = next[i].copyWith(status: CrashStatus.sent);
        state = state.copyWith(reports: next);
        changed = true;
      }
      if (changed && mounted) await _save();
    } catch (e) {
      debugPrint('crash flush failed (ignored): $e');
    } finally {
      _flushing = false;
    }
  }

  /// Dev tool: drop the local copies. Anything already delivered stays on the
  /// server.
  Future<void> clear() async {
    await _ready;
    state = state.copyWith(reports: const []);
    await _save();
  }
}
