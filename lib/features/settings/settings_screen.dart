import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/health.dart';
import '../../data/achievements_catalog.dart';
import '../../data/shop_catalog.dart';
import '../../state/app_providers.dart';
import '../stats/statistics_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final level = healthLevelInfo(player.healthLevel);
    final fmt = NumberFormat.decimalPattern();

    final shopItems = kShopCatalog.where((i) => i.inShop).length;
    final trophies = kAchievements.where((a) => a.unlocked(player)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // The full breakdown is a screen of its own — this is just the door.
          ListTile(
            title: const Text('Statistics'),
            subtitle: Text('$trophies trophies · '
                '${fmt.format(player.lifetimeSteps)} lifetime steps · '
                '${player.owned.length}/$shopItems items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
          const Divider(),

          // The step target isn't the player's to set any more — the health
          // ladder fixes it — so this is read-only.
          const _SectionHeader('How health works'),
          ListTile(
            title: Text('Currently ${level.name}'),
            subtitle: Text(
              '${fmt.format(kHoldSteps)} steps a day holds your level · '
              '${fmt.format(kClimbSteps)} climbs one · '
              'below ${fmt.format(kHoldSteps)} you slip one',
            ),
            isThreeLine: true,
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text(
                'Health data is used only to count steps. Never sold, never sent to ads.'),
          ),
          // Progress wipe is a developer tool — never expose it in a release
          // build where a stray tap nukes a paying player's wallet.
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              title: const Text('Reset progress (debug)',
                  style: TextStyle(color: Colors.red)),
              subtitle: const Text('Wipes wallet, inventory and streak'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset everything?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset')),
                    ],
                  ),
                );
                if (confirmed == true) await controller.resetProgress();
              },
            ),
          ],
          const AboutListTile(
            applicationName: 'StepQuest',
            applicationVersion: '0.1.0 (Phase 0 prototype)',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}
