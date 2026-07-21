import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/bible.dart';
import 'package:step_quest/core/spheres.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('verse of the day', () {
    test('is stable within a day and rotates across days', () {
      final a = verseForToday(DateTime(2026, 7, 22));
      final b = verseForToday(DateTime(2026, 7, 22, 23, 59));
      expect(a.reference, b.reference); // same all day

      // Consecutive days give consecutive entries in the list.
      final d0 = verseForToday(DateTime(2026, 1, 1));
      final d1 = verseForToday(DateTime(2026, 1, 2));
      expect(d0.reference, isNot(d1.reference));
    });

    test('every day of a year maps to a real verse', () {
      for (var i = 0; i < 366; i++) {
        final v = verseForToday(DateTime(2024, 1, 1).add(Duration(days: i)));
        expect(v.text, isNotEmpty);
        expect(v.reference, isNotEmpty);
      }
    });

    test('reward odds sum to 100', () {
      final sum = kBibleRewardOdds.values.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(100.0, 0.001));
    });
  });

  group('rollRarityFromOdds', () {
    test('maps roll position to the weighted band', () {
      const odds = {Rarity.common: 70.0, Rarity.uncommon: 25.0, Rarity.rare: 5.0};
      expect(rollRarityFromOdds(odds, 0.0), Rarity.common);
      expect(rollRarityFromOdds(odds, 0.69), Rarity.common);
      expect(rollRarityFromOdds(odds, 0.80), Rarity.uncommon);
      expect(rollRarityFromOdds(odds, 0.99), Rarity.rare);
    });
  });

  group('daily reward', () {
    test('grants once per day and is then locked out', () async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.bibleReadyToday, isTrue);

      final result = await controller.claimBibleReward();
      expect(result, isNotNull); // an item or a currency bonus
      expect(controller.bibleReadyToday, isFalse); // locked for today

      // A second claim the same day pays nothing.
      final again = await controller.claimBibleReward();
      expect(again, isNull);
    });

    test('a granted item lands in the inventory', () async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final before = container.read(playerControllerProvider).owned.length;
      final result = await controller.claimBibleReward();

      final state = container.read(playerControllerProvider);
      if (result!.item != null) {
        expect(state.owned.length, before + 1);
        expect(state.owned, contains(result.item!.id));
      } else {
        // Fallback currency path — lifetime went up instead.
        expect(result.bonusSteps, greaterThan(0));
      }
    });
  });
}
