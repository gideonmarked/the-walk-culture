import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/features/stats/statistics_screen.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  testWidgets('statistics reports the real derived figures', (tester) async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});

    // Tall viewport so the whole (lazily built) list renders and every section
    // can be asserted without scrolling.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    final controller = container.read(playerControllerProvider.notifier);
    await controller.addSimulatedSteps(6000); // holds the level, short of a climb

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatisticsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Every section is present.
    for (final section in [
      'Steps',
      'Health',
      'Streak',
      'Wallet',
      'Collection',
      'Trophies',
    ]) {
      expect(find.text(section), findsWidgets, reason: 'missing $section');
    }

    // Figures are derived, not placeholders: 6,000 steps holds the level and
    // leaves exactly 4,000 to the 10,000 climb line.
    expect(find.text('6,000'), findsWidgets); // steps today
    expect(find.text('Holding this level'), findsOneWidget);
    expect(find.text('Reached'), findsWidgets); // hold line already cleared
    expect(find.text('4,000'), findsWidgets); // still to climb
    expect(find.text('Balanced'), findsOneWidget); // starting health level
    expect(find.text('4 of 7'), findsOneWidget); // rung on the ladder

    // Nothing spent or won yet.
    expect(find.text('Inactive'), findsOneWidget); // 2x boost
    expect(find.text('Opened'), findsOneWidget); // spheres-opened-today row
    expect(find.text('Ready to claim'), findsOneWidget); // trophy breakdown

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
