import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/achievements_catalog.dart';
import '../../state/app_providers.dart';

/// Trophy room (doc §6). Achievements are derived live from player state.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    // The room is a display case: only what's actually been won goes on show.
    // The full list, locked ones included, lives under Quests.
    final earned = kAchievements.where((a) => a.unlocked(player)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Trophy Room')),
      body: earned.isEmpty
          ? const _EmptyCase()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      '${earned.length} of ${kAchievements.length} earned',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    childAspectRatio: 1.3,
                    children: [
                      for (final a in earned)
                        _AchievementCard(
                          emoji: a.emoji,
                          name: a.name,
                          description: a.description,
                          unlocked: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyCase extends StatelessWidget {
  const _EmptyCase();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('No trophies yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Earned trophies are displayed here. See the full list — and what '
              "it takes — under Quests.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.emoji,
    required this.name,
    required this.description,
    required this.unlocked,
  });

  final String emoji;
  final String name;
  final String description;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(unlocked ? emoji : '🔒',
                  style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
