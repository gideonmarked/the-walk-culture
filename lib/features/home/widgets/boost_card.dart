import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_providers.dart';

/// 2x earning boost (doc §5.2 "double steps for an hour"). One free hour a day.
class BoostCard extends ConsumerStatefulWidget {
  const BoostCard({super.key});

  @override
  ConsumerState<BoostCard> createState() => _BoostCardState();
}

class _BoostCardState extends ConsumerState<BoostCard> {
  // "Active" and the minutes left come from the clock, not from state, so
  // nothing else rebuilds the card when they change. Tick once a minute.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final active = controller.boostActive;
    final available = controller.freeBoostAvailable;

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
                        : available
                            ? 'Double the Pebbles you earn for 1 hour, once a day'
                            : 'Used today — a fresh boost tomorrow',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: active || !available
                  ? null
                  : () => controller.activateBoost(),
              child: Text(active
                  ? 'Active'
                  : available
                      ? 'Activate'
                      : 'Used'),
            ),
          ],
        ),
      ),
    );
  }
}
