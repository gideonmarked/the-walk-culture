import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../state/app_providers.dart';
import '../../widgets/tier_icon.dart';

/// Currency shown as tier-coloured footprint icons with the amount beside each.
/// Tap an icon to see the tier name.
class WalletBar extends ConsumerWidget {
  const WalletBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final wallet = toWallet(player.spendableSteps);
    final fmt = NumberFormat.decimalPattern();
    final tiers =
        kTierNames.where((t) => t == 'Steps' || (wallet[t] ?? 0) > 0).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in tiers)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('${fmt.format(wallet[t] ?? 0)} $t'),
                    duration: const Duration(seconds: 2),
                  ));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    TierIcon(t, size: 26),
                    const SizedBox(width: 4),
                    Text(fmt.format(wallet[t] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
