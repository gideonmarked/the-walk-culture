import 'package:flutter_test/flutter_test.dart';
import 'package:step_quest/core/currency.dart';
import 'package:step_quest/models/shop_item.dart';

void main() {
  group('toWallet', () {
    test('breaks a total into base-100 tiers', () {
      // 1*Gold + 2*Silver + 3*Copper + 4*Steps at 100x = 1_020_304.
      final w = toWallet(1020304);
      expect(w['Steps'], 4);
      expect(w['Copper'], 3);
      expect(w['Silver'], 2);
      expect(w['Gold'], 1);
    });

    test('handles zero and negatives safely', () {
      expect(toWallet(0)['Steps'], 0);
      expect(toWallet(-50)['Steps'], 0);
    });
  });

  group('priceInSteps', () {
    test('converts tier prices to raw steps at 100x', () {
      expect(priceInSteps('Steps', 500), 500);
      expect(priceInSteps('Copper', 3), 300);
      expect(priceInSteps('Silver', 2), 20000);
      expect(priceInSteps('Gold', 1), 1000000);
    });
  });

  group('rarity tier gate', () {
    test('each rarity is priced in its own ascending tier', () {
      expect(kRarityTier[Rarity.common], 'Steps');
      expect(kRarityTier[Rarity.uncommon], 'Copper');
      expect(kRarityTier[Rarity.rare], 'Silver');
      expect(kRarityTier[Rarity.epic], 'Gold');
      expect(kRarityTier[Rarity.legendary], 'Titanium');
    });

    test('a rarity unlocks only once its tier has been banked', () {
      // Common needs nothing.
      expect(rarityTierUnlocked(Rarity.common, 0), isTrue);

      // Uncommon needs Copper (100 steps).
      expect(rarityTierUnlocked(Rarity.uncommon, 99), isFalse);
      expect(rarityTierUnlocked(Rarity.uncommon, 100), isTrue);

      // Rare needs Silver (10,000).
      expect(rarityTierUnlocked(Rarity.rare, 9999), isFalse);
      expect(rarityTierUnlocked(Rarity.rare, 10000), isTrue);

      // Epic needs Gold (1,000,000).
      expect(rarityTierUnlocked(Rarity.epic, 999999), isFalse);
      expect(rarityTierUnlocked(Rarity.epic, 1000000), isTrue);

      // Legendary needs Titanium (100,000,000).
      expect(rarityTierUnlocked(Rarity.legendary, 99999999), isFalse);
      expect(rarityTierUnlocked(Rarity.legendary, 100000000), isTrue);
    });
  });
}
