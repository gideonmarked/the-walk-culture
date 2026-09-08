import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/app_info.dart';
import 'package:step_quest/core/crash.dart';
import 'package:step_quest/core/crash_reporter.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/crash_providers.dart';
import 'package:step_quest/state/premium_providers.dart';

Future<({ProviderContainer container, CrashController crash})> _boot(
    {Map<String, Object> prefs = const {}}) async {
  kEnableBackgroundServices = false;
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer();
  // record() snapshots diagnostics from these; construct them here so their
  // async init finishes inside the test rather than after it.
  container.read(playerControllerProvider.notifier);
  container.read(premiumControllerProvider.notifier);
  final crash = container.read(crashControllerProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return (container: container, crash: crash);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('trimming', () {
    test('a long message keeps its useful head', () {
      final short = summarizeCrashMessage(StateError('boom'));
      expect(short, contains('boom'));
      expect(summarizeCrashMessage('x' * 5000).length,
          lessThanOrEqualTo(kCrashMessageMaxChars + 1));
    });

    test('a runaway stack is capped by lines and characters', () {
      final huge = List.generate(500, (i) => '#$i  someFunction (file.dart:$i)')
          .join('\n');
      final trimmed = trimStack(huge);
      expect(trimmed.split('\n').length, lessThanOrEqualTo(kCrashStackMaxLines));
      expect(trimmed.length, lessThanOrEqualTo(kCrashStackMaxChars + 2));
      // The TOP frames are the ones kept — that's where the bug is.
      expect(trimmed, startsWith('#0'));
    });

    test('a null stack is empty, not the string "null"', () {
      expect(trimStack(null), '');
      expect(trimStack('   \n  \n'), '');
    });
  });

  group('fingerprinting', () {
    test('varying numbers collapse into one bug', () {
      // The whole point: a loop that throws with a changing index is ONE bug,
      // not a hundred reports.
      final a = crashFingerprint(
          message: 'RangeError: Invalid value: Not in range 0..9: 41',
          stack: '#0 List.[] (dart:core)\n#1 build (home.dart:120)');
      final b = crashFingerprint(
          message: 'RangeError: Invalid value: Not in range 0..9: 42',
          stack: '#0 List.[] (dart:core)\n#1 build (home.dart:121)');
      expect(a, b);
    });

    test('hex addresses collapse too', () {
      expect(
        crashFingerprint(message: 'Bad state at 0xdeadbeef', stack: ''),
        crashFingerprint(message: 'Bad state at 0xcafef00d', stack: ''),
      );
    });

    test('same function, different line collapses — deliberately', () {
      // Line numbers go the way of loop indices. Two bugs on adjacent lines of
      // one function with the same message group together; that is the price
      // of not filing a report per frame, and it is the right side to err on.
      expect(
        crashFingerprint(
            message: 'Bad state', stack: '#0 build (home.dart:120)'),
        crashFingerprint(
            message: 'Bad state', stack: '#0 build (home.dart:121)'),
      );
    });

    test('genuinely different bugs stay apart', () {
      final a = crashFingerprint(
          message: 'Null check operator used on a null value',
          stack: '#0 build (shop.dart:44)');
      final b = crashFingerprint(
          message: 'Null check operator used on a null value',
          stack: '#0 build (house.dart:91)');
      expect(a, isNot(b));
    });

    test('is bounded — it is a key, not prose', () {
      final key = crashFingerprint(
          message: 'e' * 2000, stack: List.filled(50, 'f' * 200).join('\n'));
      expect(key.length, lessThanOrEqualTo(300));
    });

    test('survives having no stack at all', () {
      expect(crashFingerprint(message: 'lonely error', stack: ''), isNotEmpty);
    });
  });

  group('the outbox', () {
    test('records a crash with context, pending', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.crash.record(
          error: StateError('the pass screen blew up'),
          stack: StackTrace.current,
          kind: CrashKind.flutter,
          library: 'widgets library');

      final reports = b.container.read(crashControllerProvider).reports;
      expect(reports.length, 1);
      expect(reports.single.message, contains('the pass screen blew up'));
      expect(reports.single.kind, CrashKind.flutter);
      expect(reports.single.library, 'widgets library');
      expect(reports.single.occurrences, 1);
      expect(reports.single.isPending, isTrue);
      expect(reports.single.stack, isNotEmpty);
      expect(reports.single.diagnostics['App version'], kAppVersion);
    });

    test('a per-frame error becomes ONE report with a count', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      // Same bug, 200 times — as a layout error in build() genuinely would.
      final stack = StackTrace.current;
      for (var i = 0; i < 200; i++) {
        await b.crash.record(
            error: StateError('A RenderFlex overflowed by $i pixels'),
            stack: stack);
      }

      final reports = b.container.read(crashControllerProvider).reports;
      expect(reports.length, 1, reason: 'must not file 200 reports');
      expect(reports.single.occurrences, 200);
      expect(reports.single.lastSeenMs,
          greaterThanOrEqualTo(reports.single.firstSeenMs));
    });

    test('distinct bugs get distinct reports, newest first', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.crash.record(
          error: StateError('first bug'), stack: StackTrace.fromString('#0 a'));
      await b.crash.record(
          error: StateError('second bug'), stack: StackTrace.fromString('#0 b'));

      final reports = b.container.read(crashControllerProvider).reports;
      expect(reports.length, 2);
      expect(reports.first.message, contains('second bug'));
      expect(reports.map((r) => r.id).toSet().length, 2);
    });

    test('an unsent crash is NEVER evicted to make room', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      // Frame names must differ by more than a NUMBER — digits are normalized
      // away on purpose, so 'frame1' and 'frame2' are the same bug.
      const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN';
      for (var i = 0; i < 40; i++) {
        await b.crash.record(
            error: StateError('bug in ${letters[i]}'),
            stack: StackTrace.fromString('#0 ${letters[i]}Widget (f.dart)'));
      }
      // Nothing was delivered (no backend), so all 40 distinct bugs are kept.
      final reports = b.container.read(crashControllerProvider).reports;
      expect(reports.length, 40);
      expect(reports.every((r) => r.isPending), isTrue);
    });

    test('delivered crashes ARE trimmed to the cap', () async {
      final b = await _boot(prefs: {
        'twc_crashes_v1': jsonEncode([
          for (var i = 19; i >= 0; i--)
            {
              'id': 'old-$i',
              'fingerprint': 'delivered bug $i',
              'kind': 'flutter',
              'message': 'delivered $i',
              'stack': '#0 old',
              'firstSeenMs': 1000 + i,
              'lastSeenMs': 1000 + i,
              'status': 'sent',
            }
        ]),
      });
      addTearDown(b.container.dispose);

      await b.crash.record(
          error: StateError('brand new bug'),
          stack: StackTrace.fromString('#0 freshWidget (f.dart)'));
      final reports = b.container.read(crashControllerProvider).reports;

      expect(reports.length, 20); // cap held
      expect(reports.first.message, contains('brand new bug'));
      expect(reports.where((r) => r.isPending).length, 1);
      expect(reports.map((r) => r.message), isNot(contains('delivered 0')));
    });

    test('opting out records nothing at all', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.crash.setEnabled(false);
      await b.crash.record(error: StateError('unwanted'), stack: null);

      expect(b.container.read(crashControllerProvider).reports, isEmpty);
      expect(b.container.read(crashControllerProvider).enabled, isFalse);
    });

    test('the opt-out is remembered across a restart', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);
      await b.crash.setEnabled(false);

      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(crashControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(again.read(crashControllerProvider).enabled, isFalse);
    });

    test('survives a restart and stays queued', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);
      await b.crash.record(
          error: StateError('crashed last run'), stack: StackTrace.current);

      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(playerControllerProvider.notifier);
      again.read(premiumControllerProvider.notifier);
      again.read(crashControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final reports = again.read(crashControllerProvider).reports;
      expect(reports.length, 1);
      expect(reports.single.message, contains('crashed last run'));
      expect(reports.single.isPending, isTrue,
          reason: 'never delivered, so still queued');
    });

    test('a recurrence re-queues an already-sent report', () async {
      // The count is the interesting part of a crash report, so a bug that
      // keeps firing has to go back out with its new number.
      const sent = CrashReport(
        id: 'r1',
        fingerprint: 'boom :: #0 a',
        kind: CrashKind.flutter,
        message: 'boom',
        stack: '#0 a',
        firstSeenMs: 1,
        lastSeenMs: 1,
        status: CrashStatus.sent,
      );
      final again = sent.recur(atMs: 999);
      expect(again.occurrences, 2);
      expect(again.lastSeenMs, 999);
      expect(again.firstSeenMs, 1);
      expect(again.isPending, isTrue);
    });
  });

  group('the recorder never makes things worse', () {
    test('reporting before install is a silent no-op', () {
      CrashReporter.reset();
      // No container yet — must not throw.
      expect(() => CrashReporter.report(StateError('too early')),
          returnsNormally);
    });

    test('installed handlers stay ADDITIVE, not swallowing', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      // Stand in for Flutter's default handler and prove it still runs.
      final seenByPrevious = <Object>[];
      final savedOnError = FlutterError.onError;
      FlutterError.onError = (details) => seenByPrevious.add(details.exception);

      CrashReporter.install(b.container);
      final error = StateError('additive check');
      FlutterError.onError!(FlutterErrorDetails(
          exception: error, stack: StackTrace.current, library: 'test'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Recorded by us…
      expect(
          b.container
              .read(crashControllerProvider)
              .reports
              .any((r) => r.message.contains('additive check')),
          isTrue);
      // …AND still passed to whoever was handling errors before.
      expect(seenByPrevious, contains(error));

      FlutterError.onError = savedOnError;
      CrashReporter.reset();
    });
  });

  test('a report survives a JSON round trip', () {
    const original = CrashReport(
      id: 'c-1',
      fingerprint: 'Bad state :: #0 build (a.dart:#)',
      kind: CrashKind.async,
      message: 'Bad state: no element',
      stack: '#0 build (a.dart:12)',
      library: 'widgets library',
      firstSeenMs: 1750000000000,
      lastSeenMs: 1750000009999,
      occurrences: 7,
      diagnostics: {'App version': '0.1.0+1'},
      status: CrashStatus.sent,
    );
    final back = CrashReport.fromJson(jsonDecode(jsonEncode(original.toJson())));

    expect(back.id, original.id);
    expect(back.fingerprint, original.fingerprint);
    expect(back.kind, CrashKind.async);
    expect(back.message, original.message);
    expect(back.stack, original.stack);
    expect(back.library, original.library);
    expect(back.occurrences, 7);
    expect(back.firstSeenMs, original.firstSeenMs);
    expect(back.lastSeenMs, original.lastSeenMs);
    expect(back.diagnostics, original.diagnostics);
    expect(back.status, CrashStatus.sent);
  });

  test('an unknown kind or status degrades instead of throwing', () {
    final r = CrashReport.fromJson(const {'id': 'x', 'kind': 'wat'});
    expect(r.kind, CrashKind.async);
    expect(r.status, CrashStatus.pending);
    expect(r.occurrences, 1);
  });
}
