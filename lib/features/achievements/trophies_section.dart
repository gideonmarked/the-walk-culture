import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/achievements.dart';
import '../../data/achievements_catalog.dart';
import '../../models/player_state.dart';
import '../../state/app_providers.dart';

/// The full trophy list, easy → elite, locked ones included — this is where you
/// go to see what's still out there. The Trophy Room shows only what's earned.
/// Lives inside the caller's scroll view, so no Scaffold of its own.
class TrophiesSection extends ConsumerWidget {
  const TrophiesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final unlocked = kAchievements.where((a) => a.unlocked(player)).length;
    final claimable = kAchievements.where((a) => a.claimable(player)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trophies',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                claimable > 0
                    ? '$unlocked of ${kAchievements.length} earned  ·  '
                        '$claimable ready to claim'
                    : '$unlocked of ${kAchievements.length} earned',
                style: claimable > 0
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)
                    : null,
              ),
            ],
          ),
        ),
        for (final difficulty in Difficulty.values)
          _DifficultyGroup(difficulty: difficulty, player: player),
      ],
    );
  }
}

class _DifficultyGroup extends StatelessWidget {
  const _DifficultyGroup({required this.difficulty, required this.player});

  final Difficulty difficulty;
  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final group =
        kAchievements.where((a) => a.difficulty == difficulty).toList();
    if (group.isEmpty) return const SizedBox.shrink();

    final earned = group.where((a) => a.unlocked(player)).length;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(difficulty.label,
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text('$earned / ${group.length}'),
        children: [
          for (final a in group) _TrophyRow(achievement: a, player: player),
        ],
      ),
    );
  }
}

class _TrophyRow extends ConsumerWidget {
  const _TrophyRow({required this.achievement, required this.player});

  final Achievement achievement;
  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = achievement.unlocked(player);
    final claimable = achievement.claimable(player);
    final fmt = NumberFormat.decimalPattern();

    final Widget trailing;
    if (claimable) {
      trailing = FilledButton(
        onPressed: () async {
          final ok = await ref
              .read(playerControllerProvider.notifier)
              .claimAchievement(achievement);
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('${achievement.name} — '
                    '+${fmt.format(achievement.reward)} Steps claimed!'),
              ));
          }
        },
        child: Text('+${fmt.format(achievement.reward)}'),
      );
    } else if (earned) {
      trailing = const Chip(label: Text('Claimed'));
    } else {
      trailing = Text('+${fmt.format(achievement.reward)}',
          style: Theme.of(context).textTheme.bodySmall);
    }

    return Opacity(
      opacity: earned ? 1.0 : 0.45,
      child: ListTile(
        dense: true,
        leading: Text(earned ? achievement.emoji : '🔒',
            style: const TextStyle(fontSize: 26)),
        title: Text(achievement.name),
        subtitle: Text(achievement.description),
        trailing: trailing,
      ),
    );
  }
}
