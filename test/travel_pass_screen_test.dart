import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/app.dart';
import 'package:step_quest/core/travel_pass.dart';
import 'package:step_quest/features/pass/travel_pass_screen.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/premium_providers.dart';

/// Pump the pass screen on its own with a live container.
Future<ProviderContainer> _pumpPass(WidgetTester tester) async {
  kEnableBackgroundServices = false;
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(playerControllerProvider.notifier);
  container.read(premiumControllerProvider.notifier);
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TravelPassScreen()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the season, the two columns, and the VIP upsell',
      (tester) async {
    final container = await _pumpPass(tester);
    final season = container.read(playerControllerProvider.notifier).passSeason;

    expect(find.text('Travel Pass'), findsOneWidget); // app bar
    expect(find.text(season.name), findsOneWidget);
    expect(find.text('Level 0'), findsOneWidget);
    expect(find.text(' / $kPassLevelCount'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);

    // Non-VIP sees the upsell, and it names the exact number on offer.
    expect(find.textContaining('$vipExclusiveItemCount cosmetics'),
        findsOneWidget);

    // Nothing earned yet → no claim-all button.
    expect(find.textContaining('Claim'), findsNothing);
  });

  testWidgets('walking a level makes its free reward claimable', (tester) async {
    final container = await _pumpPass(tester);
    final player = container.read(playerControllerProvider.notifier);

    await player.addSimulatedSteps(kPassLevelXp);
    await tester.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Claim 1 reward'), findsOneWidget);

    await tester.tap(find.text('Claim 1 reward'));
    await tester.pumpAndSettle();

    // Claimed, announced, and the button is gone because nothing is left.
    expect(player.passRewardClaimed(1, vip: false), isTrue);
    expect(find.textContaining('claimed!'), findsOneWidget); // snackbar
    expect(find.text('Claim 1 reward'), findsNothing);
  });

  testWidgets('a VIP cell explains itself instead of dying silently',
      (tester) async {
    final handle = tester.ensureSemantics();
    final container = await _pumpPass(tester);
    final player = container.read(playerControllerProvider.notifier);

    await player.addSimulatedSteps(kPassLevelXp * 2);
    await tester.pumpAndSettle();

    // The cells carry their state in the semantics label, so a screen reader
    // hears "locked" / "VIP only" / "ready to claim" too.
    final vipLocked = find.bySemanticsLabel(RegExp('VIP only'));
    expect(vipLocked, findsWidgets);

    await tester.tap(vipLocked.first);
    await tester.pumpAndSettle();

    expect(find.text('VIP reward'), findsOneWidget);
    expect(find.textContaining('unlocks right away'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('an unreached VIP cell reads locked, not "VIP only"',
      (tester) async {
    final handle = tester.ensureSemantics();
    final container = await _pumpPass(tester);
    final player = container.read(playerControllerProvider.notifier);

    // Level 2 of 30 — most of the VIP column is still unwalked.
    await player.addSimulatedSteps(kPassLevelXp * 2);
    await tester.pumpAndSettle();
    expect(player.passLevel, 2);

    // Level 3's VIP reward is beyond us. It must NOT advertise itself as
    // VIP-only: the offer copy says "everything you have already walked past",
    // which would be false, and the rung loses its "keep walking" signal.
    expect(find.bySemanticsLabel(RegExp(r"Traveler's Sash, locked")),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r"Traveler's Sash, VIP only")),
        findsNothing);

    // The rung we HAVE reached still offers the subscription.
    expect(find.bySemanticsLabel(RegExp('VIP only')), findsWidgets);
    handle.dispose();
  });

  testWidgets('going VIP flips the earned VIP column to claimable',
      (tester) async {
    final handle = tester.ensureSemantics();
    final container = await _pumpPass(tester);
    final player = container.read(playerControllerProvider.notifier);

    await player.addSimulatedSteps(kPassLevelXp * 3);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('VIP only')), findsWidgets);
    final beforeClaimable = player.passClaimableCount;

    await container.read(premiumControllerProvider.notifier).grantVip(30);
    await tester.pumpAndSettle();

    // The upsell strip is gone and the locks are off.
    expect(find.textContaining('cosmetics'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('VIP only')), findsNothing);
    expect(player.passClaimableCount, greaterThan(beforeClaimable));
    expect(find.textContaining('Claim all'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the nav bar badges unclaimed pass rewards', (tester) async {
    kEnableBackgroundServices = false;
    // Start already banked into Silver. The steps below would otherwise cross
    // into Copper, and Home's tier-up celebration would throw a modal barrier
    // over the nav bar we're trying to tap.
    SharedPreferences.setMockInitialValues({
      'stepquest_player_v1': jsonEncode({'lifetimeSteps': 20000}),
    });
    final container = ProviderContainer();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const WalkCultureApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now')); // past onboarding
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    expect(find.descendant(of: navBar, matching: find.text('Pass')),
        findsOneWidget);
    // Nothing earned → no badge.
    expect(
        find.descendant(
            of: navBar, matching: find.widgetWithText(Badge, '1')),
        findsNothing);

    await container
        .read(playerControllerProvider.notifier)
        .addSimulatedSteps(kPassLevelXp);
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: navBar, matching: find.widgetWithText(Badge, '1')),
        findsOneWidget);

    // And the tab opens the pass. (Tap the icon, not the label — the label
    // sits outside the destination's hit box in a NavigationBar.)
    await tester.tap(find.byIcon(Icons.card_travel_outlined));
    await tester.pumpAndSettle();
    expect(find.text('FREE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
