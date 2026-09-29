import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/prayer_requests.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  test('praying for a request rewards every time, up to the daily cap', () async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);

    // Every prayer rewards, so each of the first N calls hands out an item/bonus.
    for (var i = 0; i < kRewardedRequestPrayersPerDay; i++) {
      expect(await controller.claimRequestPrayerReward(), isNotNull,
          reason: 'reward $i should be granted');
      expect(controller.requestPrayerRewardsLeft,
          kRewardedRequestPrayersPerDay - (i + 1));
    }

    // Past the cap the prayer still "counts" (server-side) but no reward drops.
    expect(await controller.claimRequestPrayerReward(), isNull);
    expect(controller.requestPrayerRewardsLeft, 0);
  });
}
