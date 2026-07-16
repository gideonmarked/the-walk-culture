import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/premium.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/premium_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumController', () {
    late ProviderContainer container;
    late PremiumController premium;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      premium = container.read(premiumControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() => container.dispose());

    test('starts non-VIP, becomes VIP for the granted window', () {
      expect(container.read(premiumControllerProvider).isVip, isFalse);

      premium.grantVip(7);
      final s = container.read(premiumControllerProvider);
      expect(s.isVip, isTrue);
      expect(s.vipDaysLeft, inInclusiveRange(6, 7));
    });

    test('renewals stack onto the remaining window, not reset it', () {
      premium.grantVip(30);
      final after30 = container.read(premiumControllerProvider).vipUntilMs;
      premium.grantVip(30);
      final after60 = container.read(premiumControllerProvider).vipUntilMs;
      // Second month extends from the first month's expiry (~+30 days), so the
      // gap is close to another 30 days, not a reset back to now.
      final addedDays = (after60 - after30) / Duration.millisecondsPerDay;
      expect(addedDays, inInclusiveRange(29, 31));
    });

    test('ad rewards are capped per day and the cap lifts for VIP', () {
      // Free tier: kAdRewardsPerDay watches allowed, then blocked.
      for (var i = 0; i < kAdRewardsPerDay; i++) {
        expect(premium.canWatchAd, isTrue, reason: 'watch #$i');
        expect(premium.recordAdReward(), isTrue);
      }
      expect(premium.canWatchAd, isFalse);
      expect(premium.recordAdReward(), isFalse); // over the cap → no-op

      // Going VIP grants one extra slot for today.
      premium.grantVip(30);
      expect(premium.canWatchAd, isTrue);
      expect(premium.recordAdReward(), isTrue);
      expect(premium.canWatchAd, isFalse);
    });

    test('ad-step and purchase totals accumulate for stats', () {
      premium.recordAdReward();
      premium.recordPurchasedSteps(60000);
      final s = container.read(premiumControllerProvider);
      expect(s.adStepsTotal, kAdRewardSteps);
      expect(s.purchasedStepsTotal, 60000);
    });

    test('VIP stipend is due once, then not again the same day', () async {
      expect(premium.stipendDueToday, isFalse); // not VIP yet
      await premium.grantVip(30);
      expect(premium.stipendDueToday, isTrue);
      await premium.markStipendPaid();
      expect(premium.stipendDueToday, isFalse);
    });
  });

  group('VIP earning multiplier', () {
    test('VIP doubles walked-step earnings; grants stay unmultiplied', () async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final player = container.read(playerControllerProvider.notifier);
      final premium = container.read(premiumControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Non-VIP: 1,000 walked → 1,000 currency.
      await player.addSimulatedSteps(1000);
      expect(container.read(playerControllerProvider).lifetimeSteps, 1000);

      // VIP: the next 1,000 walked earns 2×.
      await premium.grantVip(30);
      await player.addSimulatedSteps(1000);
      expect(container.read(playerControllerProvider).lifetimeSteps, 3000);

      // A purchased/ad grant is a fixed amount — NOT multiplied by VIP.
      await player.grantBonusSteps(1000);
      expect(container.read(playerControllerProvider).lifetimeSteps, 4000);
    });
  });
}
