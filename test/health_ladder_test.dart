import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/health.dart';
import 'package:step_quest/core/streaks.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyDailyHealth', () {
    test('under the hold line slips one level', () {
      expect(applyDailyHealth(3, 0), 2);
      expect(applyDailyHealth(3, kHoldSteps - 1), 2);
    });

    test('hold line to climb line keeps the level', () {
      expect(applyDailyHealth(3, kHoldSteps), 3);
      expect(applyDailyHealth(3, kClimbSteps - 1), 3);
    });

    test('climb line and above gains one level', () {
      expect(applyDailyHealth(3, kClimbSteps), 4);
      expect(applyDailyHealth(3, 50000), 4); // one level a day, never more
    });

    test('clamps at both ends of the ladder', () {
      expect(applyDailyHealth(0, 0), 0); // Idle can't go lower
      expect(applyDailyHealth(6, kClimbSteps), 6); // Soaring can't go higher
      expect(clampHealthLevel(-5), 0);
      expect(clampHealthLevel(99), kHealthLevels.length - 1);
    });

    test('the ladder runs worst to best', () {
      expect(kHealthLevels.map((l) => l.name).toList(), [
        'Idle',
        'Sluggish',
        'Strolling',
        'Steady',
        'Brisk',
        'Swift',
        'Soaring',
      ]);
      expect(healthLevelInfo(kStartHealthLevel).name, 'Steady');
      expect(isBottomHealth(0), isTrue);
      expect(isTopHealth(kHealthLevels.length - 1), isTrue);
    });
  });

  group('day rollover grading', () {
    /// Boots a controller whose save says "yesterday ended with [daySteps]".
    Future<ProviderContainer> bootWithYesterday(
        {required int daySteps, required int level}) async {
      kEnableBackgroundServices = false; // no sync to overwrite todaySteps
      final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
      SharedPreferences.setMockInitialValues({
        'stepquest_player_v1': jsonEncode({
          'todaySteps': daySteps,
          'healthLevel': level,
          'questDay': yesterday,
          'claimedQuests': ['q_3k'],
          'openedSpheres': ['bronze'],
          'sphereRewards': {'bronze': 'steps:500'},
        }),
      });
      final container = ProviderContainer();
      // Providers are lazy: read the notifier so _init() actually starts, then
      // wait for it to finish loading the save before touching state.
      container.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container;
    }

    test('a big day climbs a level and resets the day', () async {
      final container =
          await bootWithYesterday(daySteps: 12000, level: 3); // Steady
      addTearDown(container.dispose);

      // Any state touch rolls the day; simulate walking 0 steps into the new one.
      await container.read(playerControllerProvider.notifier).addSimulatedSteps(0);

      final state = container.read(playerControllerProvider);
      expect(state.healthLevel, 4); // → Brisk
      expect(state.todaySteps, 0); // fresh day
      expect(state.claimedQuests, isEmpty); // dailies reset with the roll
      expect(state.openedSpheres, isEmpty);
      expect(state.sphereRewards, isEmpty);
    });

    test('a middling day holds the level', () async {
      final container = await bootWithYesterday(daySteps: 6000, level: 3);
      addTearDown(container.dispose);

      await container.read(playerControllerProvider.notifier).addSimulatedSteps(0);

      expect(container.read(playerControllerProvider).healthLevel, 3);
    });

    test('a lazy day slips a level', () async {
      final container = await bootWithYesterday(daySteps: 1200, level: 3);
      addTearDown(container.dispose);

      await container.read(playerControllerProvider.notifier).addSimulatedSteps(0);

      expect(container.read(playerControllerProvider).healthLevel, 2); // → Strolling
    });

    test('a brand-new save is not punished for having no yesterday', () async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({}); // no save at all
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await container.read(playerControllerProvider.notifier).addSimulatedSteps(0);

      // Would be Sluggish/Strolling if the empty "yesterday" (0 steps) were graded.
      expect(container.read(playerControllerProvider).healthLevel,
          kStartHealthLevel);
    });

    test('steps added after midnight land on the new day, not the graded one',
        () async {
      final container = await bootWithYesterday(daySteps: 12000, level: 3);
      addTearDown(container.dispose);

      await container
          .read(playerControllerProvider.notifier)
          .addSimulatedSteps(700);

      final state = container.read(playerControllerProvider);
      expect(state.healthLevel, 4); // graded on yesterday's 12,000, not 12,700
      expect(state.todaySteps, 700); // the 700 belongs to today
    });
  });
}
