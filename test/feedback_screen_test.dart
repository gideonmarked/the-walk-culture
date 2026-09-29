import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/feedback.dart';
import 'package:step_quest/features/feedback/feedback_screen.dart';
import 'package:step_quest/features/settings/settings_screen.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/feedback_providers.dart';
import 'package:step_quest/state/premium_providers.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen) async {
  kEnableBackgroundServices = false;
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(playerControllerProvider.notifier);
  container.read(premiumControllerProvider.notifier);
  container.read(feedbackControllerProvider.notifier);
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('offers all three kinds and defaults to a bug report',
      (tester) async {
    await _pump(tester, const FeedbackScreen());

    expect(find.text('Send feedback'), findsOneWidget);
    for (final kind in FeedbackKind.values) {
      expect(find.text(kind.shortLabel), findsOneWidget);
    }
    // Bug is the default, so the body label is the bug prompt.
    expect(find.text(FeedbackKind.bug.label), findsOneWidget);
    expect(find.textContaining('what were you doing just before'),
        findsOneWidget);

    // No reports yet → no history section.
    expect(find.text('Your reports'), findsNothing);
  });

  testWidgets('switching to an idea changes the prompt', (tester) async {
    await _pump(tester, const FeedbackScreen());

    await tester.tap(find.text(FeedbackKind.idea.shortLabel));
    await tester.pumpAndSettle();

    expect(find.textContaining('What would you like to see?'), findsOneWidget);
  });

  testWidgets('empty text is refused and nothing is stored', (tester) async {
    final container = await _pump(tester, const FeedbackScreen());

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Write something first'), findsOneWidget);
    expect(container.read(feedbackControllerProvider), isEmpty);
  });

  testWidgets('a report is saved, confirmed, and listed as pending',
      (tester) async {
    final container = await _pump(tester, const FeedbackScreen());

    await tester.enterText(
        find.byType(TextField).first, 'Pass badge sticks at 1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    // There's no backend in a test, so the honest promise is "saved".
    expect(find.textContaining('saved'), findsOneWidget);

    final stored = container.read(feedbackControllerProvider);
    expect(stored.length, 1);
    expect(stored.single.body, 'Pass badge sticks at 1');
    expect(stored.single.isPending, isTrue);

    // …and it shows up in the history, below the form, with the
    // waiting-to-send marker.
    await tester.scrollUntilVisible(find.text('Your reports'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Your reports'), findsOneWidget);
    expect(find.text('Pass badge sticks at 1'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('the attached diagnostics are disclosed in full before sending',
      (tester) async {
    await _pump(tester, const FeedbackScreen());

    expect(find.text('What gets attached'), findsOneWidget);
    expect(find.textContaining('no journal or prayer text'), findsOneWidget);

    // Expand it — the player can read every key/value before they hit send.
    await tester.tap(find.text('What gets attached'));
    await tester.pumpAndSettle();

    expect(find.text('App version'), findsOneWidget);
    expect(find.text('Travel Pass'), findsOneWidget);
    expect(find.text('Health sync'), findsOneWidget);
  });

  testWidgets('Settings has the door to it', (tester) async {
    await _pump(tester, const SettingsScreen());

    expect(find.text('Feedback'), findsOneWidget); // section header
    final entry = find.text('Report a bug or suggest a feature');
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Send feedback'), findsOneWidget);
  });
}
