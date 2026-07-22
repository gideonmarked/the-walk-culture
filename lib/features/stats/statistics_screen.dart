import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/achievements.dart';
import '../../core/currency.dart';
import '../../core/health.dart';
import '../../core/quests.dart';
import '../../core/spheres.dart';
import '../../core/streaks.dart' show dayKey;
import '../../data/achievements_catalog.dart';
import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';
import '../../state/premium_providers.dart';
import '../spheres/spheres_screen.dart' show kRarityColor, rarityLabel;

/// Everything the player state knows, in one place. Read-only, icon-free —
/// these are figures, not actions.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final premium = ref.watch(premiumControllerProvider);
    final fmt = NumberFormat.decimalPattern();

    final level = healthLevelInfo(player.healthLevel);
    final steps = player.todaySteps;

    // --- steps / health ----------------------------------------------------
    final verdict = steps >= kClimbSteps
        ? 'Climbing a level'
        : steps >= kHoldSteps
            ? 'Holding this level'
            : 'Slipping a level';
    final toHold = steps >= kHoldSteps ? 0 : kHoldSteps - steps;
    final toClimb = steps >= kClimbSteps ? 0 : kClimbSteps - steps;

    // --- wallet ------------------------------------------------------------
    final wallet = toWallet(player.spendableSteps);
    final walletTiers =
        kTierNames.where((t) => (wallet[t] ?? 0) > 0).toList();
    final topTier = kTierNames[
        highestTierIndex(player.lifetimeSteps).clamp(0, kTierNames.length - 1)];

    // --- collection --------------------------------------------------------
    final shopItems = kShopCatalog.where((i) => i.inShop).toList();
    final ownedItems =
        kShopCatalog.where((i) => player.owned.contains(i.id)).toList();

    // --- spheres -----------------------------------------------------------
    final openedTiers = [
      for (final t in kSphereTiers)
        if (player.openedSpheres.contains(t.id)) t,
    ];
    final stepSpheres = kSphereTiers.where((t) => !t.isRealMoney).length;
    var sphereBonusSteps = 0;
    var sphereItems = 0;
    for (final code in player.sphereRewards.values) {
      final reward = decodeSphereReward(code);
      if (reward.itemId != null) {
        sphereItems++;
      } else {
        sphereBonusSteps += reward.bonusSteps;
      }
    }

    // --- trophies ----------------------------------------------------------
    final earned = kAchievements.where((a) => a.unlocked(player)).toList();
    final claimable = kAchievements.where((a) => a.claimable(player)).toList();
    final claimedSteps = kAchievements
        .where((a) => player.claimedAchievements.contains(a.id))
        .fold<int>(0, (sum, a) => sum + a.reward);
    final unclaimedSteps =
        claimable.fold<int>(0, (sum, a) => sum + a.reward);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        children: [
          const _Header('Pebbles'),
          _Stat('Steps today', fmt.format(steps)), // walked steps (activity)
          _Stat('Lifetime Pebbles earned', fmt.format(player.lifetimeSteps)),
          _Stat('Pebbles spent', fmt.format(player.spentSteps)),
          _Stat('Pebbles to spend', fmt.format(player.spendableSteps)),
          _Stat('Bonus Pebbles from spheres today',
              fmt.format(sphereBonusSteps)),
          _Stat('Bonus Pebbles from trophies', fmt.format(claimedSteps)),

          const _Header('Health'),
          _Stat('Current level', level.name),
          _Stat('Rung on the ladder',
              '${player.healthLevel + 1} of ${kHealthLevels.length}'),
          _Stat("Today's outcome", verdict),
          _Stat('Steps to hold your level',
              toHold == 0 ? 'Reached' : fmt.format(toHold)),
          _Stat('Steps to climb a level',
              toClimb == 0 ? 'Reached' : fmt.format(toClimb)),

          const _Header('Streak'),
          _Stat('Current streak', '${player.streakCurrent} days'),
          _Stat('Best streak', '${player.streakBest} days'),
          _Stat('Last qualifying day',
              player.lastGoalMetDate.isEmpty ? '—' : player.lastGoalMetDate),

          const _Header('Premium'),
          _Stat('VIP', premium.isVip ? '${premium.vipDaysLeft} days left' : 'Not active'),
          _Stat('Pebbles from purchases', fmt.format(premium.purchasedStepsTotal)),
          _Stat('Pebbles from ads', fmt.format(premium.adStepsTotal)),
          _Stat('Ads watched today',
              '${premium.adRewardsDay == dayKey(DateTime.now()) ? premium.adRewardsToday : 0}'
                  ' / ${premium.adRewardLimit}'),

          const _Header('Wallet'),
          _Stat('Highest tier reached', topTier),
          if (walletTiers.isEmpty)
            const _Stat('Balance', 'Empty')
          else
            for (final t in walletTiers) _Stat(t, fmt.format(wallet[t] ?? 0)),
          _Stat('2× earning boost',
              controller.boostActive ? 'Active' : 'Inactive'),

          const _Header('Collection'),
          _Stat('Items owned', '${ownedItems.length} / ${shopItems.length}'),
          for (final rarity in kRarityOrder)
            _RarityStat(
              rarity: rarity,
              owned: ownedItems.where((i) => i.rarity == rarity).length,
              total: shopItems.where((i) => i.rarity == rarity).length,
            ),
          _Stat('Equipped', '${player.equipped.length} / ${ItemSlot.values.length}'),
          _Stat('Decor placed', '${player.placedHome.length}'),

          const _Header('Mystery Spheres (today)'),
          _Stat('Opened', '${openedTiers.length} / $stepSpheres'),
          _Stat('Items won', '$sphereItems'),
          if (openedTiers.isNotEmpty)
            _Stat('Which',
                openedTiers.map((t) => t.name.split(' ').first).join(', ')),

          const _Header('Quests (today)'),
          _Stat('Claimed', '${player.claimedQuests.length} / ${kDailyQuests.length}'),
          for (final q in kDailyQuests)
            _Stat(
              q.title,
              player.claimedQuests.contains(q.id)
                  ? 'Claimed'
                  : q.isCompleted(player)
                      ? 'Ready'
                      : '${fmt.format(steps)} / ${fmt.format(q.effectiveTarget(player))}',
            ),

          const _Header('Trophies'),
          _Stat('Earned', '${earned.length} / ${kAchievements.length}'),
          for (final d in Difficulty.values)
            _Stat(
              d.label,
              '${earned.where((a) => a.difficulty == d).length} / '
                  '${kAchievements.where((a) => a.difficulty == d).length}',
            ),
          _Stat('Ready to claim', '${claimable.length}'),
          _Stat('Unclaimed Pebble rewards', fmt.format(unclaimedSteps)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// Owned-vs-total for one rarity, tinted with that rarity's colour so the
/// collection reads the same way it does in the shop and the Collection grid.
class _RarityStat extends StatelessWidget {
  const _RarityStat(
      {required this.rarity, required this.owned, required this.total});

  final Rarity rarity;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final color = kRarityColor[rarity];

    return ListTile(
      dense: true,
      title: Text('  ${rarityLabel(rarity)}',
          style: TextStyle(color: color)),
      trailing: Text('$owned / $total',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: color)),
    );
  }
}
