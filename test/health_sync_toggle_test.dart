import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/services/health_service.dart';
import 'package:step_quest/state/app_providers.dart';

/// Stands in for HealthKit / Health Connect with a fixed "today" total.
class _FakeHealth extends HealthService {
  _FakeHealth(this.steps);
  int? steps;

  @override
  Future<int?> getTodaySteps() async => steps;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const healthTotal = 1885; // what the phone's health store reports

  late ProviderContainer container;
  late PlayerController controller;

  /// Boots a controller that has already synced once, so todaySteps == health.
  Future<void> boot() async {
    // syncSteps() is inert unless background services are on — this suite is
    // specifically about what sync does, so it has to run for real.
    kEnableBackgroundServices = true;
    SharedPreferences.setMockInitialValues({'stepquest_onboarded_v1': true});

    container = ProviderContainer(
      overrides: [
        healthServiceProvider.overrideWithValue(_FakeHealth(healthTotal)),
      ],
    );
    controller = container.read(playerControllerProvider.notifier);

    // Let the async pref loads land (onboarding + health-sync flag). The sync
    // inside _init() races them and can no-op; the app's 5s poll covers that,
    // so here we just sync once explicitly instead of leaving a timer running.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.stopAutoSync(); // no periodic timer left ticking in the test
    await controller.syncSteps();

    expect(container.read(playerControllerProvider).todaySteps, healthTotal);
  }

  tearDown(() {
    kEnableBackgroundServices = false;
    container.dispose();
  });

  test('sync ON: a poll reverts simulated steps to the health total', () async {
    await boot();

    await controller.addSimulatedSteps(777);
    expect(container.read(playerControllerProvider).todaySteps, 2662);

    await controller.syncSteps(); // the poll that used to eat the 777

    expect(container.read(playerControllerProvider).todaySteps, healthTotal);
  });

  test('sync OFF: simulated steps survive a poll', () async {
    await boot();

    await container.read(healthSyncProvider.notifier).setEnabled(false);

    await controller.addSimulatedSteps(777);
    expect(container.read(playerControllerProvider).todaySteps, 2662);

    await controller.syncSteps(); // must be a no-op now

    expect(container.read(playerControllerProvider).todaySteps, 2662);

    // And they keep accumulating rather than snapping back to health.
    await controller.addSimulatedSteps(1000);
    await controller.syncSteps();
    expect(container.read(playerControllerProvider).todaySteps, 3662);
  });

  test('sync OFF then ON again resumes following health', () async {
    await boot();

    await container.read(healthSyncProvider.notifier).setEnabled(false);
    await controller.addSimulatedSteps(777);
    await controller.syncSteps();
    expect(container.read(playerControllerProvider).todaySteps, 2662);

    await container.read(healthSyncProvider.notifier).setEnabled(true);
    await controller.syncSteps();

    expect(container.read(playerControllerProvider).todaySteps, healthTotal);
  });
}
