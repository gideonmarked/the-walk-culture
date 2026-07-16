import 'package:flutter/material.dart';

import 'tier_icon.dart';

/// Celebration shown when the player first reaches a new currency tier (doc §6).
void showTierUpDialog(BuildContext context, String tier) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TierIcon(tier, size: 72),
          const SizedBox(height: 12),
          Text('$tier tier reached!',
              style: Theme.of(ctx).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('New cosmetics are within reach. Keep walking!',
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Nice!'),
        ),
      ],
    ),
  );
}
