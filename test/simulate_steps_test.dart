import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/features/home/widgets/simulate_steps_card.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    kEnableBackgroundServices = false; // no timers/health/pedometer in tests
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SimulateStepsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  int todaySteps() => container.read(playerControllerProvider).todaySteps;

  testWidgets('preset chip credits its own amount', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('+500'));
    await tester.pumpAndSettle();
    expect(todaySteps(), 500);

    // A different preset credits a different amount — not a hardcoded 500.
    await tester.tap(find.text('+5K'));
    await tester.pumpAndSettle();
    expect(todaySteps(), 5500);

    await teardown(tester);
  });

  testWidgets('custom dialog credits the typed amount', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(todaySteps(), 1234);

    // Reopening prefills with the last custom amount.
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '1234'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(todaySteps(), 1234); // cancel credits nothing

    await teardown(tester);
  });

  testWidgets('custom dialog rejects zero', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a number above 0'), findsOneWidget);
    expect(todaySteps(), 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await teardown(tester);
  });
}
