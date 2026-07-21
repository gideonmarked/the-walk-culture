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

    // The Spheres tab is gone: 4 destinations, none of them Spheres.
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Spheres'), findsNothing);

    // Quests now leads with the spheres section, quest list underneath.
    await tester.tap(find.text('Quests'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Quests'), findsOneWidget); // app bar

    // Spheres are at the top of the list, so they render without scrolling.
    expect(find.text('Mystery Spheres'), findsOneWidget); // section heading
    expect(find.textContaining('Reach each step goal'), findsOneWidget);

    // ...and they sit above the quest list: the quest blurb starts off-screen
    // and only appears once scrolled past the spheres.
    expect(find.textContaining('Complete quests'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('Complete quests'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Complete quests'), findsOneWidget);

    // Only the shell's and Quests' own Scaffolds — the section brought none,
    // i.e. it's embedded in the quests scroll view rather than pushed as a route.
    expect(find.byType(Scaffold), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
