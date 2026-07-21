import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/prayer.dart';
import 'package:step_quest/core/spheres.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/gratitude_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, PlayerController)> boot() async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    final ctrl = c.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return (c, ctrl);
  }

  group('prayer walk', () {
    test('is a 1000-step walk with prompts every 200 steps', () {
      expect(kPrayerWalkTargetSteps, 1000);
      expect(kPrayerWalkPromptInterval, 200);
      // Enough prompts to cover each interval up to the target.
      expect(kPrayerWalkPrompts.length,
          greaterThanOrEqualTo(kPrayerWalkTargetSteps ~/ kPrayerWalkPromptInterval));
    });

    test('reward grants once per day', () async {
      final (c, ctrl) = await boot();
      addTearDown(c.dispose);
      expect(ctrl.prayerWalkReadyToday, isTrue);
      expect(await ctrl.claimPrayerWalkReward(), isNotNull);
      expect(ctrl.prayerWalkReadyToday, isFalse);
      expect(await ctrl.claimPrayerWalkReward(), isNull);
    });
  });

  group('gratitude', () {
    test('the reward roll is always common, whatever the dice', () {
      // Gratitude grants from a 100%-common table — no roll value can escape it.
      const gratitudeOdds = {Rarity.common: 100.0};
      for (var i = 0; i <= 100; i++) {
        expect(rollRarityFromOdds(gratitudeOdds, i / 100), Rarity.common);
      }
    });

    test('claiming grants a common item, once per day', () async {
      final (c, ctrl) = await boot();
      addTearDown(c.dispose);
      expect(ctrl.gratitudeReadyToday, isTrue);
      final result = await ctrl.claimGratitudeReward();
      expect(result, isNotNull);
      expect(result!.rarity, Rarity.common);
      expect(ctrl.gratitudeReadyToday, isFalse);
      expect(await ctrl.claimGratitudeReward(), isNull);
    });

    test('journal entries are stored, and never leak into the synced save',
        () async {
      final (c, _) = await boot();
      addTearDown(c.dispose);

      await c
          .read(gratitudeJournalProvider.notifier)
          .addEntry('2026-7-22', ['my family', 'a warm meal', 'rest']);
      expect(c.read(gratitudeJournalProvider).first.items, hasLength(3));

      // The player save (what syncs to the backend) must contain no reflection
      // text — only the claim DATE is allowed to travel.
      final saveJson = c.read(playerControllerProvider).toJson().toString();
      expect(saveJson.contains('warm meal'), isFalse);
      expect(saveJson.contains('my family'), isFalse);
    });

    test('blank lines are dropped from an entry', () async {
      final (c, _) = await boot();
      addTearDown(c.dispose);
      await c
          .read(gratitudeJournalProvider.notifier)
          .addEntry('2026-7-22', ['thankful', '   ', '']);
      expect(c.read(gratitudeJournalProvider).first.items, ['thankful']);
    });
  });
}
