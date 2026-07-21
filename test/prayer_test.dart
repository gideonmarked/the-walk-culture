import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/prayer.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prayer is a two-minute activity', () {
    expect(kPrayerDuration, const Duration(minutes: 2));
  });

  test('prayer reward odds sum to 100', () {
    final sum = kPrayerRewardOdds.values.fold<double>(0, (a, b) => a + b);
    expect(sum, closeTo(100.0, 0.001));
  });

  test('prompt is stable within a day, rotates across days', () {
    expect(prayerPromptForToday(DateTime(2026, 7, 22)),
        prayerPromptForToday(DateTime(2026, 7, 22, 23)));
    expect(prayerPromptForToday(DateTime(2026, 1, 1)),
        isNot(prayerPromptForToday(DateTime(2026, 1, 2))));
  });

  test('reward grants once per day, then locks out', () async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.prayerReadyToday, isTrue);
    final result = await controller.claimPrayerReward();
    expect(result, isNotNull);
    expect(controller.prayerReadyToday, isFalse);
    expect(await controller.claimPrayerReward(), isNull); // second claim no-op
  });

  test('prayer and bible rewards are independent that same day', () async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Claiming one must not lock the other — they track separate dates.
    await controller.claimBibleReward();
    expect(controller.bibleReadyToday, isFalse);
    expect(controller.prayerReadyToday, isTrue);

    await controller.claimPrayerReward();
    expect(controller.prayerReadyToday, isFalse);
  });
}
