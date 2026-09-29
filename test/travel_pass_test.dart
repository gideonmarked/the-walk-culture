import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/prayer_requests.dart';
import 'package:step_quest/core/quests.dart';
import 'package:step_quest/core/spheres.dart';
import 'package:step_quest/core/travel_pass.dart';
import 'package:step_quest/data/achievements_catalog.dart';
import 'package:step_quest/data/pass_catalog.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/player_state.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/state/app_providers.dart';
import 'package:step_quest/state/notifications.dart';
import 'package:step_quest/state/premium_providers.dart';

/// Boot a container with the background services inert, wait out the async
/// loads, and hand back the two controllers the pass touches.
Future<
    ({
      ProviderContainer container,
      PlayerController player,
      PremiumController premium,
    })> _boot({Map<String, Object> prefs = const {}}) async {
  kEnableBackgroundServices = false;
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer();
  final player = container.read(playerControllerProvider.notifier);
  final premium = container.read(premiumControllerProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return (container: container, player: player, premium: premium);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('level maths', () {
    test('a level costs a flat kPassLevelXp, and the track caps at 30', () {
      expect(passLevelForXp(0), 0);
      expect(passLevelForXp(kPassLevelXp - 1), 0);
      expect(passLevelForXp(kPassLevelXp), 1);
      expect(passLevelForXp(kPassLevelXp * 7 + 10), 7);
      expect(passLevelForXp(xpForLevel(kPassLevelCount)), kPassLevelCount);
      // Walking past the end doesn't invent level 31.
      expect(passLevelForXp(xpForLevel(kPassLevelCount) * 3), kPassLevelCount);
    });

    test('progress fills between levels and reads full once maxed', () {
      expect(passXpIntoLevel(0), 0);
      expect(passXpIntoLevel(kPassLevelXp + 2000), 2000);
      expect(passLevelProgress(kPassLevelXp + kPassLevelXp ~/ 2), 0.5);
      // A maxed track must not dangle a bar that can never fill.
      final maxed = xpForLevel(kPassLevelCount) + 1234;
      expect(passXpIntoLevel(maxed), 0);
      expect(passLevelProgress(maxed), 1);
    });

    test('a season is walkable: full track under the health-holding pace', () {
      // 30 levels across kSeasonDays must cost less per day than the 5,000
      // steps that merely HOLDS your health level — otherwise the pass would
      // demand more than the game's own baseline.
      final perDay = xpForLevel(kPassLevelCount) / kSeasonDays;
      expect(perDay, lessThan(5000));
    });
  });

  group('seasons', () {
    test('derived from the epoch, 60 days apart, never negative', () {
      expect(seasonAt(kSeasonEpoch).index, 0);
      expect(seasonAt(kSeasonEpoch).id, 's0');
      expect(
          seasonAt(kSeasonEpoch.add(const Duration(days: kSeasonDays - 1)))
              .index,
          0);
      expect(seasonAt(kSeasonEpoch.add(const Duration(days: kSeasonDays))).index,
          1);
      expect(
          seasonAt(kSeasonEpoch.add(const Duration(days: kSeasonDays * 4 + 3)))
              .index,
          4);
      // A device with a badly wrong clock lands on season 0, not a negative one.
      expect(seasonAt(kSeasonEpoch.subtract(const Duration(days: 500))).index, 0);
    });

    test('window and countdown line up with the index', () {
      final season = seasonAt(kSeasonEpoch.add(const Duration(days: 70)));
      expect(season.index, 1);
      expect(season.start, kSeasonEpoch.add(const Duration(days: 60)));
      expect(season.end, kSeasonEpoch.add(const Duration(days: 120)));
      // 70 days in → 50 to go.
      expect(season.daysLeftAt(kSeasonEpoch.add(const Duration(days: 70))), 50);
      // A part-day left still reads as a day, never 0.
      expect(season.daysLeftAt(season.end.subtract(const Duration(hours: 3))), 1);
      expect(season.daysLeftAt(season.end), 0);
    });

    test('names cycle through the themes so seasons never run out', () {
      final first = seasonAt(kSeasonEpoch);
      final wrapped = seasonAt(
          kSeasonEpoch.add(Duration(days: kSeasonDays * kSeasonThemes.length)));
      expect(first.name, contains('Season 1'));
      expect(wrapped.theme.name, first.theme.name); // same theme, new number
      expect(wrapped.name, isNot(first.name));
    });
  });

  group('the reward track', () {
    test('is 30 rungs, in order, with the VIP column never empty', () {
      expect(kPassTrack.length, kPassLevelCount);
      for (var i = 0; i < kPassTrack.length; i++) {
        expect(kPassTrack[i].level, i + 1);
      }
      expect(passLevelAt(0), isNull);
      expect(passLevelAt(kPassLevelCount + 1), isNull);
      expect(passLevelAt(1)!.level, 1);
    });

    test('every item reward points at a real pass cosmetic', () {
      final ids = {for (final i in kPassCatalog) i.id};
      for (final rung in kPassTrack) {
        for (final reward in [rung.free, rung.vip]) {
          if (reward?.kind != PassRewardKind.item) continue;
          expect(ids, contains(reward!.itemId),
              reason: 'level ${rung.level} rewards a missing item');
          expect(passRewardItem(reward), isNotNull);
        }
      }
    });

    test('no cosmetic is handed out on both tracks or twice on one', () {
      final granted = <String>[];
      for (final rung in kPassTrack) {
        for (final reward in [rung.free, rung.vip]) {
          if (reward?.kind == PassRewardKind.item) granted.add(reward!.itemId);
        }
      }
      expect(granted.toSet().length, granted.length);
      // And the catalog carries no spares — every pass item is actually earnable.
      expect(granted.toSet(), {for (final i in kPassCatalog) i.id});
    });

    test('the VIP column is where the exclusives are', () {
      final freeItems = kPassTrack
          .where((l) => l.free?.kind == PassRewardKind.item)
          .length;
      // Free players still get real cosmetics — just fewer, and the VIP column
      // holds the clear majority. That split IS the offer.
      expect(freeItems, greaterThan(0));
      expect(vipExclusiveItemCount, greaterThan(freeItems));
    });

    test('rarity climbs the track: the last rung is the best thing on it', () {
      final capstone = passRewardItem(kPassTrack.last.vip)!;
      expect(capstone.rarity, Rarity.celestial);
      for (final rung in kPassTrack) {
        final item = rung.vip.kind == PassRewardKind.item
            ? passRewardItem(rung.vip)
            : null;
        if (item == null || rung.level >= kPassLevelCount) continue;
        expect(kRarityOrder.indexOf(item.rarity),
            lessThanOrEqualTo(kRarityOrder.indexOf(capstone.rarity)),
            reason: '${item.id} outranks the level-30 capstone');
      }
    });
  });

  group('exclusivity', () {
    test('pass cosmetics are unsellable and flagged exclusive', () {
      for (final item in kPassCatalog) {
        expect(item.passExclusive, isTrue, reason: item.id);
        expect(item.inShop, isFalse, reason: item.id);
        expect(item.costInSteps, 0, reason: item.id);
        // The shop-gate rule still applies: priced in its rarity's own tier.
        expect(item.priceTier, kRarityTier[item.rarity], reason: item.id);
      }
    });

    test('the random-roll pool cannot contain a pass item', () {
      // This is the whole guarantee: spheres and the daily devotion rolls draw
      // from kRollableCatalog, so a lucky roll can never hand over a VIP-track
      // cosmetic for free.
      expect(kRollableCatalog.any((i) => i.passExclusive), isFalse);
      for (final item in kPassCatalog) {
        expect(kRollableCatalog.map((i) => i.id), isNot(contains(item.id)));
        expect(kShopCatalog.map((i) => i.id), contains(item.id)); // still equippable
      }
      // Nothing else was lost from the pool along the way.
      expect(kRollableCatalog.length, kShopCatalog.length - kPassCatalog.length);
    });

    test('pass items stay off the shop shelves', () {
      final onSale = kShopCatalog.where((i) => i.inShop).map((i) => i.id).toSet();
      for (final item in kPassCatalog) {
        expect(onSale, isNot(contains(item.id)));
      }
    });
  });

  group('earning XP', () {
    test('XP is RAW walked steps — VIP and boost multiply currency only', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(1000);
      expect(b.container.read(playerControllerProvider).passXp, 1000);
      expect(b.container.read(playerControllerProvider).lifetimeSteps, 1000);

      // VIP doubles the currency…
      await b.premium.grantVip(30);
      await b.player.addSimulatedSteps(1000);
      expect(b.container.read(playerControllerProvider).lifetimeSteps, 3000);
      // …but NOT the track. Money must not buy progress on the pass.
      expect(b.container.read(playerControllerProvider).passXp, 2000);

      // Same for the temporary boost (VIP + boost = 4× currency, 1× XP).
      await b.player.activateBoost();
      await b.player.addSimulatedSteps(1000);
      expect(b.container.read(playerControllerProvider).lifetimeSteps, 7000);
      expect(b.container.read(playerControllerProvider).passXp, 3000);
    });

    test('bought and watched steps earn no XP at all', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.grantBonusSteps(100000); // an IAP pack / ad reward
      expect(b.container.read(playerControllerProvider).lifetimeSteps, 100000);
      expect(b.container.read(playerControllerProvider).passXp, 0);
      expect(b.player.passLevel, 0);
    });

    test('quests and spheres chip in, gently', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(3000); // clears the 3k quest
      final afterSteps = b.container.read(playerControllerProvider).passXp;
      final quest = kDailyQuests.first;
      expect(await b.player.claimQuest(quest), isTrue);
      expect(b.container.read(playerControllerProvider).passXp,
          afterSteps + kPassXpPerQuest);

      // Gentle means gentle. Cash in EVERYTHING a day can offer that isn't a
      // step — every quest, all nine devotion rolls (the four practices plus
      // the capped request prayers), every openable sphere — and it still has
      // to be a fraction of one level, or walking stops being how you climb.
      const devotionRolls = 4 + kRewardedRequestPrayersPerDay;
      final openableSpheres =
          kSphereTiers.where((t) => !t.isRealMoney).length;
      final maxSideXpPerDay = kPassXpPerQuest * kDailyQuests.length +
          kPassXpPerDevotion * devotionRolls +
          kPassXpPerSphere * openableSpheres;
      expect(maxSideXpPerDay, lessThan(kPassLevelXp ~/ 4));
    });

    test('a level-up lands in the inbox once', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(kPassLevelXp);
      expect(b.player.passLevel, 1);
      final notes = b.container
          .read(notificationsProvider)
          .where((n) => n.title.contains('Travel Pass level'));
      expect(notes.length, 1);
      expect(notes.single.title, contains('level 1'));

      // More steps inside level 1 → no second announcement.
      await b.player.addSimulatedSteps(10);
      expect(
          b.container
              .read(notificationsProvider)
              .where((n) => n.title.contains('Travel Pass level'))
              .length,
          1);
    });
  });

  group('claiming', () {
    test('the free track: reach it, claim it, once', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      // Nothing is claimable at level 0.
      expect(b.player.passRewardClaimable(1, vip: false), isFalse);
      expect(await b.player.claimPassReward(1, vip: false), isNull);

      await b.player.addSimulatedSteps(kPassLevelXp);
      expect(b.player.passRewardClaimable(1, vip: false), isTrue);

      final before = b.container.read(playerControllerProvider).lifetimeSteps;
      final reward = await b.player.claimPassReward(1, vip: false);
      expect(reward, isNotNull);
      expect(reward!.kind, PassRewardKind.pebbles);
      expect(b.container.read(playerControllerProvider).lifetimeSteps,
          before + reward.amount);

      // A double-tap pays nothing.
      expect(await b.player.claimPassReward(1, vip: false), isNull);
      expect(b.player.passRewardClaimed(1, vip: false), isTrue);
    });

    test('an item reward lands in the inventory, ready to equip', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      final level = kPassTrack
          .firstWhere((l) => l.free?.kind == PassRewardKind.item)
          .level;
      await b.player.addSimulatedSteps(xpForLevel(level));

      final reward = await b.player.claimPassReward(level, vip: false);
      expect(reward!.kind, PassRewardKind.item);
      final owned = b.container.read(playerControllerProvider).owned;
      expect(owned, contains(reward.itemId));

      final item = kShopCatalog.firstWhere((i) => i.id == reward.itemId);
      await b.player.equip(item);
      expect(b.container.read(playerControllerProvider).equipped[item.slot],
          item.id);
    });

    test('an empty free cell is never claimable', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);
      await b.player.addSimulatedSteps(xpForLevel(kPassLevelCount));

      final blank = kPassTrack.firstWhere((l) => l.free == null).level;
      expect(b.player.passRewardClaimable(blank, vip: false), isFalse);
      expect(await b.player.claimPassReward(blank, vip: false), isNull);
      // The VIP cell at that rung is real, though.
      expect(passLevelAt(blank)!.vip, isNotNull);
    });

    test('off-track levels are refused', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);
      await b.player.addSimulatedSteps(xpForLevel(kPassLevelCount) * 2);

      expect(await b.player.claimPassReward(0, vip: false), isNull);
      expect(await b.player.claimPassReward(kPassLevelCount + 1, vip: true),
          isNull);
      expect(b.player.passRewardClaimable(-3, vip: true), isFalse);
    });
  });

  group('the VIP track', () {
    test('locked without VIP, however far you have walked', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(xpForLevel(kPassLevelCount));
      expect(b.player.passLevel, kPassLevelCount); // free players max the track

      for (var level = 1; level <= kPassLevelCount; level++) {
        expect(b.player.passRewardClaimable(level, vip: true), isFalse,
            reason: 'level $level');
        expect(await b.player.claimPassReward(level, vip: true), isNull);
      }
      // …while the free column is entirely open.
      expect(b.player.passRewardClaimable(1, vip: false), isTrue);
    });

    test('subscribing retro-unlocks every VIP reward already earned', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(xpForLevel(10));
      expect(b.player.passRewardClaimable(10, vip: true), isFalse);

      await b.premium.grantVip(30);
      for (var level = 1; level <= 10; level++) {
        expect(b.player.passRewardClaimable(level, vip: true), isTrue,
            reason: 'level $level');
      }
      // Not beyond where they've actually walked, though.
      expect(b.player.passRewardClaimable(11, vip: true), isFalse);
    });

    test('a lapsed VIP keeps what they claimed, loses what they did not',
        () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(xpForLevel(5));
      await b.premium.grantVip(30);
      final claimed = await b.player.claimPassReward(3, vip: true);
      expect(claimed, isNotNull);

      await b.premium.clearVip();
      // Kept: the claim stands and, if it was a cosmetic, so does the item.
      expect(b.player.passRewardClaimed(3, vip: true), isTrue);
      if (claimed!.kind == PassRewardKind.item) {
        expect(b.container.read(playerControllerProvider).owned,
            contains(claimed.itemId));
      }
      // Lost: everything still unclaimed re-locks.
      expect(b.player.passRewardClaimable(4, vip: true), isFalse);
    });

    test('claim-all sweeps both columns in one save', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(xpForLevel(kPassLevelCount));
      await b.premium.grantVip(30);

      final expected = b.player.passClaimableCount;
      expect(expected, greaterThan(kPassLevelCount)); // both columns, 30 rungs
      final claimed = await b.player.claimAllPassRewards();
      expect(claimed.length, expected);
      expect(b.player.passClaimableCount, 0);
      // Nothing left to sweep.
      expect(await b.player.claimAllPassRewards(), isEmpty);
    });

    test('claim-all pays out the whole track: pebbles, items and boosts',
        () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(xpForLevel(kPassLevelCount));
      await b.premium.grantVip(30);
      final before = b.container.read(playerControllerProvider);
      final claimed = await b.player.claimAllPassRewards();
      final after = b.container.read(playerControllerProvider);

      final pebbles = claimed
          .where((r) => r.kind == PassRewardKind.pebbles)
          .fold(0, (sum, r) => sum + r.amount);
      expect(after.lifetimeSteps, before.lifetimeSteps + pebbles);

      final items = claimed
          .where((r) => r.kind == PassRewardKind.item)
          .map((r) => r.itemId)
          .toSet();
      expect(items.length, kPassCatalog.length); // the full set, both columns
      expect(after.owned, containsAll(items));

      // Boost hours stack instead of overwriting, so the last one claimed
      // doesn't throw the rest away.
      final hours = claimed
          .where((r) => r.kind == PassRewardKind.boost)
          .fold(0, (sum, r) => sum + r.hours);
      expect(hours, greaterThan(0));
      final boostMsLeft =
          after.boostUntilMs - DateTime.now().millisecondsSinceEpoch;
      expect(boostMsLeft,
          greaterThan((hours - 1) * Duration.millisecondsPerHour));
    });
  });

  group('season rollover', () {
    test('a stale season wipes XP and claims on load', () async {
      final b = await _boot(prefs: {
        'stepquest_player_v1': jsonEncode({
          'lifetimeSteps': 500000,
          'owned': ['pass_trail_cap'],
          'passSeasonId': 's-last-year',
          'passXp': 123456,
          'claimedPassFree': ['1', '2', '3'],
          'claimedPassVip': ['1'],
        }),
      });
      addTearDown(b.container.dispose);

      final state = b.container.read(playerControllerProvider);
      expect(state.passSeasonId, seasonAt(DateTime.now()).id);
      expect(state.passXp, 0);
      expect(state.claimedPassFree, isEmpty);
      expect(state.claimedPassVip, isEmpty);
      // Rewards already banked are NOT clawed back — only the track resets.
      expect(state.owned, contains('pass_trail_cap'));
      expect(state.lifetimeSteps, 500000);
      // And the player is told.
      expect(
          b.container
              .read(notificationsProvider)
              .where((n) => n.title.contains('new Travel Pass season'))
              .length,
          1);
    });

    test('the current season survives a reload, silently', () async {
      final b = await _boot(prefs: {
        'stepquest_player_v1': jsonEncode({
          'passSeasonId': seasonAt(DateTime.now()).id,
          'passXp': 40000,
          'claimedPassFree': ['1'],
        }),
      });
      addTearDown(b.container.dispose);

      final state = b.container.read(playerControllerProvider);
      expect(state.passXp, 40000);
      expect(state.claimedPassFree, {'1'});
      expect(b.player.passLevel, 5);
      expect(
          b.container
              .read(notificationsProvider)
              .where((n) => n.title.contains('new Travel Pass season')),
          isEmpty);
    });

    test('a save from before the pass starts a season without announcing one',
        () async {
      final b = await _boot(prefs: {
        'stepquest_player_v1': jsonEncode({'lifetimeSteps': 9000}),
      });
      addTearDown(b.container.dispose);

      final state = b.container.read(playerControllerProvider);
      expect(state.passSeasonId, seasonAt(DateTime.now()).id);
      expect(state.passXp, 0);
      expect(
          b.container
              .read(notificationsProvider)
              .where((n) => n.title.contains('new Travel Pass season')),
          isEmpty);
    });

    test('a dev reset clears the track too', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.addSimulatedSteps(kPassLevelXp * 2);
      await b.player.claimPassReward(1, vip: false);
      expect(b.container.read(playerControllerProvider).passXp, greaterThan(0));

      await b.player.resetProgress();
      final state = b.container.read(playerControllerProvider);
      expect(state.passXp, 0);
      expect(state.claimedPassFree, isEmpty);
      expect(state.claimedPassVip, isEmpty);
    });
  });

  group('rollover safety', () {
    test('a clock behind the calendar must NOT wipe the track', () async {
      // Seasons only ever move forward, so a stored season AHEAD of the
      // derived one means the clock is wrong — a dead RTC, a pre-NTP boot,
      // someone winding the date back. Treating that as a rollover would
      // destroy a real season's progress permanently.
      final b = await _boot(prefs: {
        'stepquest_player_v1': jsonEncode({
          'passSeasonId': 's9999',
          'passXp': 120000,
          'claimedPassFree': ['1', '2', '3'],
          'claimedPassVip': ['1', '2'],
        }),
      });
      addTearDown(b.container.dispose);

      final state = b.container.read(playerControllerProvider);
      expect(state.passSeasonId, 's9999');
      expect(state.passXp, 120000);
      expect(state.claimedPassFree, {'1', '2', '3'});
      expect(state.claimedPassVip, {'1', '2'});
      expect(
          b.container
              .read(notificationsProvider)
              .where((n) => n.title.contains('new Travel Pass season')),
          isEmpty);
    });

    test('seasonIndexFromId reads back what the season wrote', () {
      expect(seasonIndexFromId('s0'), 0);
      expect(seasonIndexFromId('s47'), 47);
      expect(seasonIndexFromId(seasonAt(DateTime.now()).id),
          seasonAt(DateTime.now()).index);
      // Anything we don't recognise must not be mistaken for a season number.
      expect(seasonIndexFromId(''), isNull);
      expect(seasonIndexFromId('s'), isNull);
      expect(seasonIndexFromId('s-last-year'), isNull);
      expect(seasonIndexFromId('4'), isNull);
    });

    test('the rollover reaches DISK, not just memory', () async {
      // A player who opens the app on rollover day and walks nowhere gets no
      // other save — the reset has to be persisted by the roll itself.
      final b = await _boot(prefs: {
        'stepquest_player_v1': jsonEncode({
          'passSeasonId': 's-last-year',
          'passXp': 99999,
          'claimedPassFree': ['1'],
        }),
      });
      addTearDown(b.container.dispose);

      final prefs = await SharedPreferences.getInstance();
      final onDisk = jsonDecode(prefs.getString('stepquest_player_v1')!)
          as Map<String, dynamic>;
      expect(onDisk['passSeasonId'], seasonAt(DateTime.now()).id);
      expect(onDisk['passXp'], 0);
      expect(onDisk['claimedPassFree'], isEmpty);
    });

    test('the announcement survives an inbox that already has entries',
        () async {
      // Reading notificationsProvider is what CONSTRUCTS its controller, and
      // the season roll is the first read. The controller's own async load
      // must merge with the note already added, not overwrite it.
      final b = await _boot(prefs: {
        'stepquest_player_v1': jsonEncode({'passSeasonId': 's-last-year'}),
        'twc_notifications_v1': jsonEncode([
          {
            'id': 'older-thing',
            'kind': 'system',
            'title': 'Something earlier',
            'body': 'b',
            'createdAtMs': 1,
            'read': true,
          }
        ]),
      });
      addTearDown(b.container.dispose);

      final inbox = b.container.read(notificationsProvider);
      expect(inbox.where((n) => n.title.contains('new Travel Pass season')).length,
          1);
      expect(inbox.where((n) => n.id == 'older-thing').length, 1,
          reason: 'the merge must not drop the saved history either');
    });
  });

  group('knock-on effects of adding 17 items to the catalog', () {
    test('a pass exclusive can never be bought, even priced at 0', () async {
      final b = await _boot();
      addTearDown(b.container.dispose);

      await b.player.grantBonusSteps(100000000); // rich enough for anything
      final exclusive = kPassCatalog.first;
      expect(exclusive.costInSteps, 0); // …which is exactly the danger
      expect(await b.player.buy(exclusive), isFalse);
      expect(b.container.read(playerControllerProvider).owned,
          isNot(contains(exclusive.id)));
    });

    test('the Collector trophy still means every SHOP item', () {
      final shopIds = {
        for (final i in kShopCatalog)
          if (i.inShop) i.id,
      };
      final collector = kAchievements.firstWhere((a) => a.id == 'collector');

      // Owning every reward-only item (pass exclusives + sphere loot) must not
      // count toward "own every shop item".
      final rewardOnly = {
        for (final i in kShopCatalog)
          if (!i.inShop) i.id,
      };
      expect(rewardOnly.length, greaterThanOrEqualTo(kPassCatalog.length));
      expect(collector.unlocked(PlayerState(owned: rewardOnly)), isFalse);

      // The real thing does.
      expect(collector.unlocked(PlayerState(owned: shopIds)), isTrue);
    });
  });

  test('pass fields survive a JSON round trip', () async {
    final b = await _boot();
    addTearDown(b.container.dispose);

    await b.player.addSimulatedSteps(kPassLevelXp * 3);
    await b.premium.grantVip(30);
    await b.player.claimPassReward(2, vip: true);
    await b.player.claimPassReward(1, vip: false);

    final saved = b.container.read(playerControllerProvider).toJson();
    final reloaded = PlayerState.fromJson(jsonDecode(jsonEncode(saved)));
    expect(reloaded.passXp, kPassLevelXp * 3);
    expect(reloaded.passSeasonId, seasonAt(DateTime.now()).id);
    expect(reloaded.claimedPassVip, {'2'});
    expect(reloaded.claimedPassFree, {'1'});
  });
}
