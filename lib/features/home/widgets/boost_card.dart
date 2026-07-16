import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_providers.dart';

/// 2x earning boost (doc §5.2 "double steps for an hour").
class BoostCard extends ConsumerWidget {
  const BoostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final active = controller.boostActive;

    String remaining() {
      final ms = player.boostUntilMs - DateTime.now().millisecondsSinceEpoch;
      final mins = (ms / 60000).ceil();
      return mins > 0 ? '$mins min left' : '';
    }

    return Card(
      color: active
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(active ? '2× boost active' : 'Earning boost',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    active
                        ? remaining()
                        : 'Double the Steps you earn for 1 hour',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: active ? null : () => controller.activateBoost(),
              child: Text(active ? 'Active' : 'Activate'),
            ),
          ],
        ),
      ),
    );
  }
}
