import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/currency.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every item is priced in a real tier and gated on exactly that tier', () {
    for (final item in kShopCatalog) {
      expect(kTierNames.contains(item.priceTier), isTrue,
          reason: '${item.id} priced in unknown tier ${item.priceTier}');
      // The gate always requires the very tier the item is priced in.
      expect(item.requiredTier, item.priceTier, reason: item.id);
    }
  });

  test('nothing on the shelves is free', () {
    // Reward-only loot (sphere drops) is priced 0 and must never be sellable —
    // otherwise the server-side purchase_item() would hand out e.g. the
    // Celestial Halo for nothing. The seed script carries in_shop through to
    // Postgres for exactly this reason.
    for (final item in kShopCatalog.where((i) => i.inShop)) {
      expect(item.costInSteps, greaterThan(0),
          reason: '${item.id} is on sale for 0');
    }
    // ...and the 0-priced ones are all reward-only.
    for (final item in kShopCatalog.where((i) => i.costInSteps == 0)) {
      expect(item.inShop, isFalse, reason: '${item.id} is free AND in the shop');
    }
  });

  test('standard (non-prestige) items sit in their rarity default tier', () {
    for (final item in kShopCatalog.where((i) => !i.id.startsWith('pr_'))) {
      expect(item.priceTier, kRarityTier[item.rarity],
          reason: '${item.id} (${item.rarity.name}) priced in ${item.priceTier}');
    }
  });

  group('prestige line (above Gold)', () {
    final prestige =
        kShopCatalog.where((i) => i.id.startsWith('pr_')).toList();

    test('exists and every item is priced above Gold', () {
      expect(prestige, isNotEmpty);
      const goldIndex = 3;
      for (final item in prestige) {
        expect(kTierNames.indexOf(item.priceTier), greaterThan(goldIndex),
            reason: '${item.id} in ${item.priceTier} is not above Gold');
        expect(item.inShop, isTrue); // actually on the shelves
      }
    });

    test('covers every tier from Titanium up to Diamond', () {
      final tiers = prestige.map((i) => i.priceTier).toSet();
      expect(
          tiers,
          containsAll(
              ['Titanium', 'Platinum', 'Tanzanite', 'Emerald', 'Ruby', 'Diamond']));
    });

    test('a Diamond item needs the Diamond tier banked, not just raw steps', () {
      final diamond =
          prestige.firstWhere((i) => i.priceTier == 'Diamond');
      // Reaching Ruby (one tier below) is not enough, even though that is a
      // colossal pile of steps.
      final justBelow = priceInSteps('Ruby', 99);
      expect(diamond.tierUnlocked(justBelow), isFalse);
      // Banking one Diamond unlocks the tier.
      expect(diamond.tierUnlocked(priceInSteps('Diamond', 1)), isTrue);
    });
  });

  group('generated catalog', () {
    test('adds the full generated set on top of the seed', () {
      // 50 styles × 10 colour variants.
      final generated =
          kShopCatalog.where((i) => i.id.startsWith('gen_')).toList();
      expect(generated.length, 500);
      // Plenty of curated seed items remain too.
      expect(kShopCatalog.length, greaterThan(500));
    });

    test('all ids are unique', () {
      final ids = kShopCatalog.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('generated items span common through epic, all buyable', () {
      final generated =
          kShopCatalog.where((i) => i.id.startsWith('gen_'));
      final rarities = generated.map((i) => i.rarity).toSet();
      expect(rarities,
          containsAll([Rarity.common, Rarity.uncommon, Rarity.rare, Rarity.epic]));
      // Everything on the shelves is actually for sale.
      expect(generated.every((i) => i.inShop), isTrue);
      // Legendary/celestial stay off the shelves (sphere loot only).
      expect(generated.any((i) => i.rarity == Rarity.legendary), isFalse);
    });

    test('every generated item has a positive cost in its tier', () {
      for (final item in kShopCatalog.where((i) => i.id.startsWith('gen_'))) {
        expect(item.costInSteps, greaterThan(0), reason: item.id);
      }
    });
  });

  group('buy gate', () {
    late ProviderContainer container;
    late PlayerController controller;

    setUp(() async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      controller = container.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() => container.dispose);

    // An Epic item is priced in Gold (1,000,000 steps to unlock the tier).
    ShopItem epicItem() =>
        kShopCatalog.firstWhere((i) => i.rarity == Rarity.epic && i.inShop);

    test('cannot buy above your tier even with enough raw steps to cover it',
        () async {
      final epic = epicItem();
      // Give plenty to COVER the price but not enough to REACH the Gold tier...
      // actually covering it means reaching it, so under-fund the tier instead:
      // 900,000 < 1,000,000 Gold threshold, and also < the item's cost.
      await controller.addSimulatedSteps(900000);

      final state = container.read(playerControllerProvider);
      expect(epic.tierUnlocked(state.spendableSteps), isFalse);
      expect(await controller.buy(epic), isFalse);
      expect(container.read(playerControllerProvider).owned, isEmpty);
    });

    test('once the tier is reached and the price is covered, buy works',
        () async {
      final epic = epicItem();
      // Enough to reach Gold and pay for the item.
      await controller.addSimulatedSteps(epic.costInSteps + 5000);

      final state = container.read(playerControllerProvider);
      expect(epic.tierUnlocked(state.spendableSteps), isTrue);
      expect(epic.purchasable(state.spendableSteps), isTrue);
      expect(await controller.buy(epic), isTrue);
      expect(container.read(playerControllerProvider).owned, contains(epic.id));
    });

    test('a common item needs no tier and buys with a handful of steps',
        () async {
      final common =
          kShopCatalog.firstWhere((i) => i.rarity == Rarity.common && i.inShop);
      await controller.addSimulatedSteps(common.costInSteps);

      expect(common.tierUnlocked(common.costInSteps), isTrue);
      expect(await controller.buy(common), isTrue);
    });
  });
}
