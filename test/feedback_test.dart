import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/app_info.dart';
import 'package:step_quest/core/feedback.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/feedback_providers.dart';
import 'package:step_quest/state/premium_providers.dart';

Future<({ProviderContainer container, FeedbackController feedback})> _boot(
    {Map<String, Object> prefs = const {}}) async {
  kEnableBackgroundServices = false;
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer();
  // submit() snapshots diagnostics from these, so construct them here and let
  // their async init finish inside the test rather than after it.
  container.read(playerControllerProvider.notifier);
  container.read(premiumControllerProvider.notifier);
  final feedback = container.read(feedbackControllerProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return (container: container, feedback: feedback);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kAppVersion matches pubspec.yaml', () {
    // A bug report is close to useless if it names the wrong build, and the
    // constant is hand-kept (no package_info_plus). So pin it here.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim();
    expect(kAppVersion, declared,
        reason: 'bump kAppVersion in lib/core/app_info.dart to match pubspec');
  });

  group('validation', () {
    test('rejects nothing-at-all, accepts real text', () {
      expect(validateFeedbackBody(''), isNotNull);
      expect(validateFeedbackBody('   \n  '), isNotNull);
      expect(validateFeedbackBody('The pass tab crashes on open'), isNull);
    });

    test('caps the body length', () {
      expect(validateFeedbackBody('x' * kFeedbackMaxChars), isNull);
      expect(validateFeedbackBody('x' * (kFeedbackMaxChars + 1)), isNotNull);
    });
  });

  group('the outbox', () {
    test('a report is stored even with no backend at all', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      // No Supabase configured, so the send cannot possibly land — the report
      // still has to survive. This is the whole promise of the screen.
      final problem = await b.feedback.submit(
        kind: FeedbackKind.bug,
        body: 'Pass badge shows 1 after claiming',
      );
      expect(problem, isNull);

      final reports = b.container.read(feedbackControllerProvider);
      expect(reports.length, 1);
      expect(reports.single.kind, FeedbackKind.bug);
      expect(reports.single.body, 'Pass badge shows 1 after claiming');
      expect(reports.single.isPending, isTrue);
      expect(b.feedback.pendingCount, 1);
    });

    test('a rejected report is not stored', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      expect(await b.feedback.submit(kind: FeedbackKind.idea, body: '  '),
          isNotNull);
      expect(b.container.read(feedbackControllerProvider), isEmpty);
    });

    test('it survives a restart and stays pending', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);
      await b.feedback.submit(
          kind: FeedbackKind.idea, body: 'Let me rename my pet');

      // Reload from the same prefs, as a relaunch would.
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('twc_feedback_v1');
      expect(saved, isNotNull);

      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(feedbackControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final reports = again.read(feedbackControllerProvider);
      expect(reports.length, 1);
      expect(reports.single.body, 'Let me rename my pet');
      expect(reports.single.isPending, isTrue,
          reason: 'still undelivered, so it must still be queued');
    });

    test('body and contact are trimmed; blank contact means no reply wanted',
        () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.feedback.submit(
        kind: FeedbackKind.other,
        body: '  spacing everywhere  ',
        contact: '   ',
      );
      final report = b.container.read(feedbackControllerProvider).single;
      expect(report.body, 'spacing everywhere');
      expect(report.contact, '');
    });

    test('an undelivered report is NEVER evicted to make room', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      // 35 reports with no backend at all — every one is still queued, so
      // every one must survive. Dropping an undelivered report is the single
      // thing this outbox exists to prevent.
      for (var i = 0; i < 35; i++) {
        await b.feedback
            .submit(kind: FeedbackKind.bug, body: 'report number $i');
      }
      final reports = b.container.read(feedbackControllerProvider);
      expect(reports.length, 35);
      expect(reports.every((r) => r.isPending), isTrue);
      expect(reports.first.body, 'report number 34'); // newest first
      // Every id distinct, or the server's dedupe would eat real reports.
      expect(reports.map((r) => r.id).toSet().length, reports.length);
    });

    test('delivered receipts ARE trimmed to the cap', () async {
      // 30 already-sent receipts on disk, then a fresh report. The new one is
      // kept and an old delivered receipt is dropped — the server has those.
      final b = await _boot(prefs: {
        'twc_feedback_v1': jsonEncode([
          for (var i = 29; i >= 0; i--)
            {
              'id': 'old-$i',
              'kind': 'bug',
              'body': 'delivered $i',
              'createdAtMs': 1000 + i,
              'status': 'sent',
            }
        ]),
      });
      addTearDown(b.container.dispose);

      await b.feedback.submit(kind: FeedbackKind.idea, body: 'the new one');
      final reports = b.container.read(feedbackControllerProvider);

      expect(reports.length, 30); // cap held
      expect(reports.first.body, 'the new one');
      expect(reports.where((r) => r.isPending).length, 1);
      // The oldest delivered receipt made way for it.
      expect(reports.map((r) => r.body), isNot(contains('delivered 0')));
    });

    test('a report queued while the outbox was still loading is not lost',
        () async {
      // Reading the provider is what constructs the controller, so a submit can
      // land before its async load returns. The load must merge, not overwrite.
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({
        'twc_feedback_v1': jsonEncode([
          {
            'id': 'older',
            'kind': 'idea',
            'body': 'from a previous run',
            'createdAtMs': 1,
            'status': 'sent',
          }
        ]),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(playerControllerProvider.notifier);
      container.read(premiumControllerProvider.notifier);

      // Submit IMMEDIATELY, without settling the load first — the outbox is
      // still reading from disk at this point.
      final controller = container.read(feedbackControllerProvider.notifier);
      await controller.submit(
          kind: FeedbackKind.bug, body: 'filed during startup');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final bodies =
          container.read(feedbackControllerProvider).map((r) => r.body);
      expect(bodies, contains('filed during startup'));
      expect(bodies, contains('from a previous run'));
    });
  });

  group('diagnostics', () {
    test('carry the build and progress, and nothing private', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.container
          .read(playerControllerProvider.notifier)
          .addSimulatedSteps(9000);
      final d = b.feedback.currentDiagnostics;

      expect(d['App version'], kAppVersion);
      expect(d['Travel Pass'], contains('level 1'));
      expect(d['VIP'], 'no');
      expect(d['Steps today'], '9000');
      expect(d['Backend'], 'offline');
      expect(d.keys, contains('Health level'));

      // Nothing that could carry a reflection, an identity, or a contact the
      // player didn't type (design invariant #3).
      final joined = '${d.keys.join('|')}|${d.values.join('|')}'.toLowerCase();
      for (final forbidden in [
        'gratitude',
        'prayer',
        'account code',
        'username',
        'email',
      ]) {
        expect(joined, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('are snapshotted onto the report, not read back later', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.feedback.submit(kind: FeedbackKind.bug, body: 'at 0 steps');
      final atSubmit =
          b.container.read(feedbackControllerProvider).single.diagnostics;
      expect(atSubmit['Steps today'], '0');

      // Walking on must not rewrite the context an old report was filed with.
      await b.container
          .read(playerControllerProvider.notifier)
          .addSimulatedSteps(5000);
      expect(
          b.container.read(feedbackControllerProvider).single
              .diagnostics['Steps today'],
          '0');
    });
  });

  test('a report survives a JSON round trip', () {
    const original = FeedbackReport(
      id: 'abc-123',
      kind: FeedbackKind.idea,
      body: 'Weekly leaderboard for my group',
      createdAtMs: 1750000000000,
      contact: 'walker@example.com',
      diagnostics: {'App version': '0.1.0+1', 'VIP': 'active'},
      lastError: 'Waiting for a connection',
    );
    final back =
        FeedbackReport.fromJson(jsonDecode(jsonEncode(original.toJson())));

    expect(back.id, original.id);
    expect(back.kind, FeedbackKind.idea);
    expect(back.body, original.body);
    expect(back.contact, original.contact);
    expect(back.diagnostics, original.diagnostics);
    expect(back.createdAtMs, original.createdAtMs);
    expect(back.status, FeedbackStatus.pending);
    expect(back.lastError, original.lastError);
  });

  test('an unknown kind or status degrades instead of throwing', () {
    final r = FeedbackReport.fromJson(const {
      'id': 'x',
      'kind': 'wat',
      'body': 'b',
      'createdAtMs': 5,
      'status': 'nonsense',
    });
    expect(r.kind, FeedbackKind.other);
    expect(r.status, FeedbackStatus.pending);
  });
}
