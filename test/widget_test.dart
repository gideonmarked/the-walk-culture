import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/app.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  testWidgets('app boots to onboarding, then shows the shell after skip',
      (tester) async {
    kEnableBackgroundServices = false; // no timers/health/pedometer in tests
    SharedPreferences.setMockInitialValues({});

    // Explicit container so we can dispose it (and its auto-sync timer)
    // deterministically before the test's pending-timer check runs.
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const StepQuestApp()),
    );
    await tester.pumpAndSettle();

    // First launch → consent-first onboarding (doc §3.6).
    expect(find.text('Connect health data'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    // Lands on the main shell.
    expect(find.text('StepQuest'), findsOneWidget); // Home app bar title
    expect(find.text('Shop'), findsWidgets); // nav destination label

    // Unmount, then dispose providers so the auto-sync timer is cancelled.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
