import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/features/shop/shop_screen.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/premium_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final puppy = kShopCatalog.firstWhere((i) => i.id == 'pet_dog');

  test('every pet on sale is VIP-store stock; nothing else is', () {
    for (final item in kShopCatalog.where((i) => i.inShop)) {
      expect(item.vipStoreOnly, item.slot == ItemSlot.pet, reason: item.id);
    }
  });

  group('buying a pet', () {
    late ProviderContainer c;

    setUp(() async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      c = ProviderContainer();
      c.read(premiumControllerProvider.notifier);
      await c
          .read(playerControllerProvider.notifier)
          .addSimulatedSteps(puppy.costInSteps + 1000);
    });
    tearDown(() => c.dispose());

    test('is refused without VIP, even when affordable', () async {
      expect(puppy.purchasable(c.read(playerControllerProvider).spendableSteps),
          isTrue);
      expect(await c.read(playerControllerProvider.notifier).buy(puppy), isFalse);
      expect(c.read(playerControllerProvider).owned, isNot(contains(puppy.id)));
    });

    test('works with VIP', () async {
      await c.read(premiumControllerProvider.notifier).grantVip(30);
      expect(await c.read(playerControllerProvider.notifier).buy(puppy), isTrue);
    });
  });

  Future<ProviderContainer> pumpShop(WidgetTester tester, {required bool vip}) async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.runAsync(() async {
      c.read(premiumControllerProvider.notifier);
      c.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (vip) await c.read(premiumControllerProvider.notifier).grantVip(30);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: ShopScreen()),
    ));
    await tester.pump();
    return c;
  }

  testWidgets('non-VIPs see no pets in the shop', (tester) async {
    await pumpShop(tester, vip: false);
    expect(find.text('👑 VIP Pets', skipOffstage: false), findsNothing);
    expect(find.text('Pet'), findsNothing);
  });

  testWidgets('VIPs get the VIP pet shelf', (tester) async {
    await pumpShop(tester, vip: true);
    // The chip row scrolls sideways; pets sit near its end.
    await tester.scrollUntilVisible(find.text('👑 VIP Pets'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('👑 VIP Pets'));
    await tester.pump();
    expect(find.text(puppy.name), findsOneWidget);
  });
}
