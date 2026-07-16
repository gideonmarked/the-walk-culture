import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('earn → buy → equip loop', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // let _init settle

    // Earn (health is unavailable in tests, so use the simulator path).
    await controller.addSimulatedSteps(500);
    expect(container.read(playerControllerProvider).lifetimeSteps, 500);

    final plant = kShopCatalog.firstWhere((i) => i.id == 'home_plant');
    expect(plant.costInSteps <= 500, true);

    // Buy succeeds and deducts.
    expect(await controller.buy(plant), true);
    var state = container.read(playerControllerProvider);
    expect(state.owned.contains('home_plant'), true);
    expect(state.spentSteps, plant.costInSteps);

    // Cannot re-buy the same item.
    expect(await controller.buy(plant), false);

    // Cannot afford something out of range.
    final crown = kShopCatalog.firstWhere((i) => i.id == 'hat_crown');
    expect(await controller.buy(crown), false);

    // Place the owned home item.
    await controller.placeHome('home_plant');
    expect(container.read(playerControllerProvider).placedHome.contains('home_plant'),
        true);
  });

  test('equip / unequip a wearable', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await controller.addSimulatedSteps(2000);
    final cap = kShopCatalog.firstWhere((i) => i.id == 'hat_cap');
    await controller.buy(cap);

    await controller.equip(cap);
    expect(container.read(playerControllerProvider).equipped[ItemSlot.hat],
        'hat_cap');

    await controller.unequip(ItemSlot.hat);
    expect(container.read(playerControllerProvider).equipped[ItemSlot.hat],
        isNull);
  });
}
