// The reworked navigation and Home: sphere progress bar maths, the Store's
// Shop/VIP tabs, and the House rooms under Profile.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/spheres.dart';
import 'package:step_quest/features/house/house_screen.dart';
import 'package:step_quest/features/store/store_screen.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  group('sphere progress', () {
    test('fills the segment toward the next sphere, in its rarity', () {
      final p = sphereProgress(12000); // between Rare (10k) and Epic (16k)
      expect(p.nextLabel, 'Epic');
      expect(p.rarity, Rarity.epic);
      expect(p.remaining, 4000);
      expect(p.fromSteps, 10000);
      expect(p.toSteps, 16000);
      expect(p.fraction, closeTo(2000 / 6000, 1e-9));
    });

    test('starts at zero toward Common', () {
      final p = sphereProgress(0);
      expect(p.nextLabel, 'Common');
      expect(p.remaining, 3000);
      expect(p.fraction, 0);
    });

    test('reaching a threshold moves on to the next rarity', () {
      final p = sphereProgress(16000);
      expect(p.nextLabel, 'Legendary');
      expect(p.fraction, 0);
    });

    test('a second sphere of the same rarity is named by the sphere', () {
      final p = sphereProgress(30000); // past Diamond (21k), toward Mythic
      expect(p.rarity, Rarity.legendary);
      expect(p.nextLabel, 'Mythic');
      expect(p.remaining, 20000);
    });

    test('past the last sphere the bar is full', () {
      final p = sphereProgress(60000);
      expect(p.allUnlocked, isTrue);
      expect(p.fraction, 1);
      expect(p.remaining, 0);
    });
  });

  testWidgets('the Store has Shop and VIP tabs', (tester) async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: StoreScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'Shop'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'VIP'), findsOneWidget);
    expect(find.text('Pebble packs'), findsNothing); // VIP tab not shown yet

    await tester.tap(find.widgetWithText(Tab, 'VIP'));
    await tester.pumpAndSettle();
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('the House holds the Closet and the Trophy Room', (tester) async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: HomeTab())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Closet'), findsOneWidget);
    expect(find.text('Trophy Room'), findsOneWidget);

    await tester.tap(find.text('Closet'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Closet'), findsOneWidget);
  });
}
