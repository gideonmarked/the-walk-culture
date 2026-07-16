import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/spheres.dart';
import 'package:step_quest/features/spheres/spheres_screen.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String idAt(int i) => kSphereTiers[i].id;

  List<String> visibleIds(Set<String> opened) => [
        for (var i = 0; i < kSphereTiers.length; i++)
          if (sphereVisible(kSphereTiers, i, opened)) kSphereTiers[i].id,
      ];

  group('sequential reveal', () {
    test('only the first sphere (plus the real-money tier) shows at the start',
        () {
      expect(visibleIds({}), ['bronze', 'celestial']);
    });

    test('steps alone do not reveal the next tier — the previous must be OPENED',
        () {
      // Even a huge step count leaves silver/gold hidden while bronze is unopened.
      expect(visibleIds({}), isNot(contains('silver')));
      expect(visibleIds({}), isNot(contains('gold')));
    });

    test('opening a sphere reveals the next and retires the opened one', () {
      final afterBronze = visibleIds({'bronze'});
      expect(afterBronze, ['silver', 'celestial']);
      expect(afterBronze, isNot(contains('bronze'))); // moved to the summary

      final afterSilver = visibleIds({'bronze', 'silver'});
      expect(afterSilver, ['gold', 'celestial']);
    });

    test('the chain only advances one tier at a time', () {
      for (var i = 0; i < kSphereTiers.length - 2; i++) {
        final opened = {for (var j = 0; j <= i; j++) idAt(j)};
        expect(visibleIds(opened), [idAt(i + 1), 'celestial']);
      }
    });
  });

  group('reward log', () {
    test('encode/decode round-trips both payout kinds', () {
      expect(decodeSphereReward('item:cap_red').itemId, 'cap_red');
      expect(decodeSphereReward('item:cap_red').bonusSteps, 0);
      expect(decodeSphereReward('steps:2000').bonusSteps, 2000);
      expect(decodeSphereReward('steps:2000').itemId, isNull);
      expect(decodeSphereReward('garbage').itemId, isNull);
      expect(decodeSphereReward('garbage').bonusSteps, 0);
    });

    test('opening a sphere records what it paid out', () async {
      kEnableBackgroundServices = false; // no health sync / timers
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.addSimulatedSteps(3000); // enough for bronze

      final bronze = kSphereTiers.first;
      final result = await controller.openSphere(bronze);
      expect(result, isNotNull);

      final state = container.read(playerControllerProvider);
      expect(state.openedSpheres, contains('bronze'));

      // The log holds the actual payout, decodable back to the same reward.
      final code = state.sphereRewards['bronze'];
      expect(code, isNotNull);
      final decoded = decodeSphereReward(code!);
      if (result!.item != null) {
        expect(decoded.itemId, result.item!.id);
      } else {
        expect(decoded.bonusSteps, result.bonusSteps);
      }
    });

    testWidgets('opened-today is an accordion: rewards appear only on expand',
        (tester) async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();

      final controller = container.read(playerControllerProvider.notifier);
      await controller.addSimulatedSteps(3000);
      final result = await controller.openSphere(kSphereTiers.first);
      expect(result, isNotNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: SpheresSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed: the header is there, but the payout detail is not built yet.
      expect(find.text('Opened today (1)'), findsOneWidget);
      expect(find.text('Bronze Sphere'), findsNothing); // retired from the list
      final rewardLabel = result!.item?.name;
      if (rewardLabel != null) {
        expect(find.text(rewardLabel), findsNothing);
      }

      await tester.tap(find.text('Opened today (1)'));
      await tester.pumpAndSettle();

      // Expanded: the sphere and what it paid out are now visible.
      expect(find.text('Bronze Sphere'), findsOneWidget);
      if (rewardLabel != null) {
        expect(find.text(rewardLabel), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    test('the log clears on a new day along with the opened set', () async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.addSimulatedSteps(3000);
      await controller.openSphere(kSphereTiers.first);
      expect(container.read(playerControllerProvider).sphereRewards, isNotEmpty);

      await controller.resetProgress();

      final state = container.read(playerControllerProvider);
      expect(state.sphereRewards, isEmpty);
      expect(state.openedSpheres, isEmpty);
    });
  });
}
