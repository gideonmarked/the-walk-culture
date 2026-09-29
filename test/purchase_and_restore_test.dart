import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/premium.dart';
import 'package:step_quest/core/streaks.dart';
import 'package:step_quest/models/player_state.dart';
import 'package:step_quest/services/cloud/cloud_sync_service.dart';
import 'package:step_quest/services/health_service.dart';
import 'package:step_quest/services/purchase_service.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/premium_providers.dart';
import 'package:step_quest/state/purchase_fulfillment.dart';

/// A backend that answers however the test says, and records what's pushed.
class _FakeCloud extends CloudSyncService {
  _FakeCloud(super.ref);

  bool ready = true;
  CloudResult<DateTime> vip = const CloudResult.none();
  CloudResult<Map<String, dynamic>> save = const CloudResult.none();
  final pushed = <Map<String, dynamic>>[];

  @override
  bool get isConfigured => true;
  @override
  bool get isReady => ready;
  @override
  Future<CloudResult<DateTime>> fetchVipUntil() async => vip;
  @override
  Future<CloudResult<Map<String, dynamic>>> pullSave() async => save;
  @override
  Future<void> pushSave(Map<String, dynamic> saveJson) async =>
      pushed.add(saveJson);
}

class _FakeHealth extends HealthService {
  _FakeHealth(this.steps);
  final int steps;
  @override
  Future<int?> getTodaySteps() async => steps;
}

const _pouch = 'com.perfeos.step_quest.currency.pouch';
const _monthly = 'com.perfeos.step_quest.vip.monthly';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pouchSteps =
      kCurrencyPacks.firstWhere((p) => p.storeProductId == _pouch).steps;

  group('purchase fulfilment', () {
    late ProviderContainer c;

    setUp(() async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      c = ProviderContainer();
      c.read(playerControllerProvider.notifier);
      c.read(premiumControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    tearDown(() => c.dispose());

    test('a pack delivered twice (e.g. restored) credits once', () async {
      final f = c.read(purchaseFulfillerProvider);
      const p = VerifiedPurchase(productId: _pouch, key: 'GPA.1');
      await Future.wait([f.fulfill(p), f.fulfill(p)]); // racing deliveries
      await f.fulfill(p); // and a later redelivery

      expect(c.read(playerControllerProvider).lifetimeSteps, pouchSteps);
      expect(c.read(premiumControllerProvider).purchasedStepsTotal, pouchSteps);
    });

    test('two different purchases of the same pack both credit', () async {
      final f = c.read(purchaseFulfillerProvider);
      await f.fulfill(const VerifiedPurchase(productId: _pouch, key: 'GPA.1'));
      await f.fulfill(const VerifiedPurchase(productId: _pouch, key: 'GPA.2'));
      expect(c.read(playerControllerProvider).lifetimeSteps, pouchSteps * 2);
    });

    test('a subscription adopts the server expiry, idempotently', () async {
      final f = c.read(purchaseFulfillerProvider);
      final until = DateTime.now().add(const Duration(days: 30));
      final p = VerifiedPurchase(productId: _monthly, key: 'tok', vipUntil: until);
      await f.fulfill(p);
      await f.fulfill(p); // re-validated on the next launch: no stacking

      expect(c.read(premiumControllerProvider).vipUntilMs,
          until.millisecondsSinceEpoch);

      // A renewal: same token, later expiry → moves forward.
      final renewed = until.add(const Duration(days: 30));
      await f.fulfill(
          VerifiedPurchase(productId: _monthly, key: 'tok', vipUntil: renewed));
      expect(c.read(premiumControllerProvider).vipUntilMs,
          renewed.millisecondsSinceEpoch);
    });
  });

  group('VIP refresh from the server', () {
    Future<(ProviderContainer, _FakeCloud)> boot(
        CloudResult<DateTime> answer) async {
      kEnableBackgroundServices = false;
      final vipUntil = DateTime.now().add(const Duration(days: 20));
      SharedPreferences.setMockInitialValues({
        'stepquest_premium_v1':
            jsonEncode({'vipUntilMs': vipUntil.millisecondsSinceEpoch}),
      });
      late _FakeCloud cloud;
      final c = ProviderContainer(overrides: [
        cloudSyncProvider.overrideWith((ref) => cloud = _FakeCloud(ref)..vip = answer),
      ]);
      c.read(premiumControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return (c, cloud);
    }

    test('a failed lookup keeps local VIP', () async {
      final (c, _) = await boot(const CloudResult.failed());
      addTearDown(c.dispose);
      expect(c.read(premiumControllerProvider).isVip, isTrue);
    });

    test('a definite "never subscribed" clears it', () async {
      final (c, _) = await boot(const CloudResult.none());
      addTearDown(c.dispose);
      expect(c.read(premiumControllerProvider).isVip, isFalse);
    });
  });

  group('cloud restore', () {
    final backup = const PlayerState(lifetimeSteps: 50000, todaySteps: 4000)
        .copyWith(questDay: dayKey(DateTime.now()))
        .toJson();

    Future<(ProviderContainer, _FakeCloud)> launch(
        CloudResult<Map<String, dynamic>> answer,
        {int health = 4000}) async {
      final c = ProviderContainer(overrides: [
        cloudSyncProvider.overrideWith((ref) => _FakeCloud(ref)..save = answer),
        healthServiceProvider.overrideWithValue(_FakeHealth(health)),
      ]);
      c.read(playerControllerProvider.notifier).stopAutoSync();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return (c, c.read(cloudSyncProvider) as _FakeCloud);
    }

    tearDown(() => kEnableBackgroundServices = false);

    test('a failed pull never pushes the fresh save, and retries next launch',
        () async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});

      // Launch 1: fresh install, the pull fails.
      final (c1, cloud1) = await launch(const CloudResult.failed());
      final player1 = c1.read(playerControllerProvider.notifier);
      await player1.addSimulatedSteps(10); // triggers a save
      await Future<void>.delayed(const Duration(seconds: 11)); // past debounce
      expect(cloud1.pushed, isEmpty, reason: 'must not overwrite the backup');
      c1.dispose();

      // Launch 2: there's a local save now, but the restore is still owed.
      final (c2, _) = await launch(CloudResult.found(backup));
      addTearDown(c2.dispose);
      expect(c2.read(playerControllerProvider).lifetimeSteps, 50000);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('restoring on the same day does not re-credit today', () async {
      kEnableBackgroundServices = true;
      SharedPreferences.setMockInitialValues({'stepquest_onboarded_v1': true});
      final (c, _) = await launch(CloudResult.found(backup), health: 4000);
      addTearDown(c.dispose);
      c.read(playerControllerProvider.notifier).stopAutoSync();
      await c.read(playerControllerProvider.notifier).syncSteps();

      // The backup's 4,000 were already banked; health still says 4,000.
      expect(c.read(playerControllerProvider).lifetimeSteps, 50000);
    });
  });
}
