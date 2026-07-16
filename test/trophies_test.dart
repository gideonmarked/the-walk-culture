import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/achievements.dart';
import 'package:step_quest/core/streaks.dart';
import 'package:step_quest/data/achievements_catalog.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Achievement byId(String id) => kAchievements.firstWhere((a) => a.id == id);

  group('catalog', () {
    test('runs easy → elite with a reward scaled to difficulty', () {
      expect(kAchievements, isNotEmpty);
      expect(byId('first_copper').difficulty, Difficulty.easy);
      expect(byId('first_copper').reward, 500);
      expect(byId('streak_100').difficulty, Difficulty.elite);
      expect(byId('streak_100').reward, 50000);

      // Every difficulty band is populated, so no group renders empty.
      for (final d in Difficulty.values) {
        expect(kAchievements.where((a) => a.difficulty == d), isNotEmpty,
            reason: 'no trophies at ${d.label}');
      }
    });

    test('ids are unique', () {
      final ids = kAchievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('claiming', () {
    late ProviderContainer container;
    late PlayerController controller;

    setUp(() async {
      kEnableBackgroundServices = false;
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      controller = container.read(playerControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() => container.dispose());

    test('an unearned trophy pays nothing', () async {
      final locked = byId('streak_100'); // 100-day streak, nowhere near
      expect(locked.unlocked(container.read(playerControllerProvider)), isFalse);

      final ok = await controller.claimAchievement(locked);

      expect(ok, isFalse);
      expect(container.read(playerControllerProvider).lifetimeSteps, 0);
    });

    test('earning a trophy makes it claimable, and it pays out once', () async {
      // 'Off the Couch' — 5,000 steps in a day.
      final trophy = byId('day_5k');
      await controller.addSimulatedSteps(5000);

      var state = container.read(playerControllerProvider);
      expect(trophy.claimable(state), isTrue);

      final before = state.lifetimeSteps;
      expect(await controller.claimAchievement(trophy), isTrue);

      state = container.read(playerControllerProvider);
      expect(state.lifetimeSteps, before + trophy.reward);
      expect(state.claimedAchievements, contains('day_5k'));
      expect(trophy.claimable(state), isFalse); // no longer offered

      // Claiming again is refused and pays nothing more.
      final after = state.lifetimeSteps;
      expect(await controller.claimAchievement(trophy), isFalse);
      expect(container.read(playerControllerProvider).lifetimeSteps, after);
    });

  });

  test('a day rollover clears quests but NOT trophy claims', () async {
    // Otherwise every trophy would pay out again, every single day.
    kEnableBackgroundServices = false;
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    SharedPreferences.setMockInitialValues({
      'stepquest_player_v1': jsonEncode({
        'todaySteps': 6000,
        'questDay': yesterday,
        'claimedQuests': ['q_3k'],
        'claimedAchievements': ['day_5k', 'first_copper'],
        'lifetimeSteps': 20000,
      }),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await controller.addSimulatedSteps(0); // triggers the day roll

    final state = container.read(playerControllerProvider);
    expect(state.claimedQuests, isEmpty); // dailies reset
    expect(state.claimedAchievements, containsAll(['day_5k', 'first_copper']));
  });
}
