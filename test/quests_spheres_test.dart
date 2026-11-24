import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/app.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  testWidgets('spheres live under quests, not in the nav bar', (tester) async {
    kEnableBackgroundServices = false; // no timers/health/pedometer in tests
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WalkCultureApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip for now')); // past onboarding
    await tester.pumpAndSettle();

    // No Spheres tab: the bar is Home / Pass / Profile.
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Spheres'), findsNothing);
    expect(find.text('Pass'), findsOneWidget);

    // Quests opens from Home's top bar and leads with the spheres section,
    // quest list underneath.
    await tester.tap(find.byTooltip('Quests'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Quests'), findsOneWidget); // app bar

    // Spheres are at the top of the list, so they render without scrolling.
    expect(find.text('Mystery Spheres'), findsOneWidget); // section heading
    expect(find.textContaining('Reach each step goal'), findsOneWidget);

    // ...and they sit above the quest list.
    await tester.scrollUntilVisible(
      find.textContaining('Complete quests'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Complete quests'), findsOneWidget);
    expect(
        tester.getTopLeft(find.textContaining('Complete quests')).dy,
        greaterThan(tester.getTopLeft(find.text('Mystery Spheres')).dy));

    // The section brought no Scaffold of its own: it's embedded in the quests
    // scroll view, so its only Scaffold ancestor is the Quests screen's.
    expect(
        find.ancestor(
            of: find.text('Mystery Spheres'), matching: find.byType(Scaffold)),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
