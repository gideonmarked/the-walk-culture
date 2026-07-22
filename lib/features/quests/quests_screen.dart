import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/quests.dart';
import '../../state/app_providers.dart';
import '../achievements/trophies_section.dart';
import '../spheres/spheres_screen.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final fmt = NumberFormat.decimalPattern();

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Quests')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SpheresSection(),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('Complete quests for bonus Pebbles. Resets daily.'),
          ),
          for (final quest in kDailyQuests)
            _QuestTile(
              quest: quest,
              todaySteps: player.todaySteps,
              target: quest.effectiveTarget(player),
              completed: quest.isCompleted(player),
              claimed: player.claimedQuests.contains(quest.id),
              fmt: fmt,
              onClaim: () async {
                final ok = await controller.claimQuest(quest);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('+${quest.reward} Pebbles claimed!')),
                  );
                }
              },
            ),
          const Divider(height: 32),
          const TrophiesSection(),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.quest,
    required this.todaySteps,
    required this.target,
    required this.completed,
    required this.claimed,
    required this.fmt,
    required this.onClaim,
  });

  final Quest quest;
  final int todaySteps;
  final int target;
  final bool completed;
  final bool claimed;
  final NumberFormat fmt;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final progress =
        target > 0 ? (todaySteps / target).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(quest.title)),
                Text('+${quest.reward}'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${fmt.format(todaySteps)} / ${fmt.format(target)}',
                    style: Theme.of(context).textTheme.bodySmall),
                if (claimed)
                  const Chip(label: Text('Claimed'))
                else
                  FilledButton(
                    onPressed: completed ? onClaim : null,
                    child: const Text('Claim'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
