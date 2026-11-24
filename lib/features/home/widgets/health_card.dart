import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/health.dart';
import '../../../core/spheres.dart';
import '../../../state/app_providers.dart';
import '../../spheres/spheres_screen.dart' show kRarityColor;

/// Today's walking at a glance: health level + streak, a progress bar toward
/// the next Mystery Sphere (coloured by the rarity being filled), and what
/// today means for tomorrow's health level.
class HealthCard extends ConsumerWidget {
  const HealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final fmt = NumberFormat.decimalPattern();
    final steps = player.todaySteps;
    final level = healthLevelInfo(player.healthLevel);

    // The live pedometer ticks between health syncs, so the count and the bar
    // move while you walk (this replaced the separate "Today" card).
    final shown = ref.watch(liveStepsProvider) ?? steps;
    final spheres = sphereProgress(shown);
    final barColor = kRarityColor[spheres.rarity] ?? Colors.grey;

    final (String status, Color color) =
        _status(context, player.healthLevel, steps);

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
                value: spheres.fraction,
                minHeight: 10,
                color: barColor,
                backgroundColor: barColor.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '${fmt.format(shown)} steps',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (spheres.allUnlocked)
                    const TextSpan(text: ' - every sphere unlocked today')
                  else ...[
                    TextSpan(
                        text:
                            ' - ${fmt.format(spheres.remaining)} more to unlock '),
                    TextSpan(
                      text: spheres.nextLabel,
                      style: TextStyle(
                          color: barColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(status,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color)),
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
        return (
          'Peak health held — nothing above ${healthLevelInfo(levelIndex).name}',
          scheme.tertiary
        );
      }
      final next = healthLevelInfo(levelIndex + 1);
      return (
        'Climbing to ${next.name} ${next.emoji} tomorrow',
        scheme.tertiary
      );
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
