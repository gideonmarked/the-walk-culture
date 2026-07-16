import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/health.dart';
import '../../../state/app_providers.dart';

/// Character health + streak. Replaces the old user-set daily goal: the player
/// can't choose a target, so this card's job is to make tomorrow's consequence
/// obvious — hold your level, climb one, or slide one.
class HealthCard extends ConsumerWidget {
  const HealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final fmt = NumberFormat.decimalPattern();
    final steps = player.todaySteps;
    final level = healthLevelInfo(player.healthLevel);

    // Bar tracks the run to a climb; below the hold line it tracks the run to
    // safety instead, so the "you're about to slip" state has its own scale.
    final holding = steps >= kHoldSteps;
    final progress = holding
        ? (steps / kClimbSteps).clamp(0.0, 1.0)
        : (steps / kHoldSteps).clamp(0.0, 1.0);

    final (String status, Color color) = _status(context, player.healthLevel, steps);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(level.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(level.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                Text('🔥 ${player.streakCurrent}'
                    '${player.streakBest > 0 ? '  ·  best ${player.streakBest}' : ''}'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(status, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              '${fmt.format(steps)} steps today',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// What today's step count means for tomorrow's level.
  (String, Color) _status(BuildContext context, int levelIndex, int steps) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.decimalPattern();

    if (steps >= kClimbSteps) {
      if (isTopHealth(levelIndex)) {
        return ('Peak health held — nothing above ${healthLevelInfo(levelIndex).name}',
            scheme.tertiary);
      }
      final next = healthLevelInfo(levelIndex + 1);
      return ('Climbing to ${next.name} ${next.emoji} tomorrow', scheme.tertiary);
    }

    if (steps >= kHoldSteps) {
      final remaining = kClimbSteps - steps;
      final next = isTopHealth(levelIndex)
          ? 'stay at ${healthLevelInfo(levelIndex).name}'
          : 'climb to ${healthLevelInfo(levelIndex + 1).name}';
      return (
        'Holding your level — ${fmt.format(remaining)} more to $next',
        scheme.primary,
      );
    }

    final remaining = kHoldSteps - steps;
    if (isBottomHealth(levelIndex)) {
      return (
        '${fmt.format(remaining)} more to hold — already at the bottom',
        scheme.error,
      );
    }
    final down = healthLevelInfo(levelIndex - 1);
    return (
      '${fmt.format(remaining)} more to hold, or you slip to ${down.name} ${down.emoji}',
      scheme.error,
    );
  }
}
