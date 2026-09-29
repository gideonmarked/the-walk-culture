import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_info.dart';
import '../../core/crash_reporter.dart';
import '../../core/dev_flags.dart';
import '../../core/health.dart';
import '../../data/achievements_catalog.dart';
import '../../data/shop_catalog.dart';
import '../../state/app_providers.dart';
import '../../state/crash_providers.dart';
import '../../state/feedback_providers.dart';
import '../feedback/feedback_screen.dart';
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
    final pendingFeedback = ref.watch(pendingFeedbackCountProvider);
    final crashes = ref.watch(crashControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // The full breakdown is a screen of its own — this is just the door.
          ListTile(
            title: const Text('Statistics'),
            subtitle: Text('$trophies trophies · '
                '${fmt.format(player.lifetimeSteps)} lifetime Pebbles · '
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
          const _SectionHeader('Diagnostics'),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined),
            title: const Text('Send crash reports'),
            subtitle: Text(crashes.enabled
                ? crashes.pendingCount > 0
                    ? '${crashes.pendingCount} waiting to send · '
                        'helps us fix what broke'
                    : 'Error details only — never your journal or prayers'
                : 'Off — nothing is recorded or sent'),
            value: crashes.enabled,
            onChanged: (on) =>
                ref.read(crashControllerProvider.notifier).setEnabled(on),
          ),
          // Proving the pipeline works is worth a button: throw, then check the
          // count above ticks up. Compiled out of a public release.
          if (kDevToolsEnabled)
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Record a test error (dev)'),
              subtitle: const Text('Files a fake crash to check reporting'),
              onTap: () {
                CrashReporter.report(
                  StateError('Test error from Settings — not a real crash'),
                  StackTrace.current,
                );
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                      content: Text('Test error recorded')));
              },
            ),
          const Divider(),
          const _SectionHeader('Feedback'),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Report a bug or suggest a feature'),
            subtitle: Text(pendingFeedback > 0
                ? '$pendingFeedback waiting to send'
                : 'Tell us what broke, or what the app should do next'),
            trailing: pendingFeedback > 0
                ? Badge(label: Text('$pendingFeedback'))
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text(
                'Health data is used only to count steps. Never sold, never sent to ads.'),
          ),
          // Progress wipe is a developer tool — kDevToolsEnabled keeps it out of
          // a public release, where a stray tap would nuke a paying player.
          if (kDevToolsEnabled) ...[
            const Divider(),
            ListTile(
              title: const Text('Reset all data (dev)',
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
          // Same constant the feedback form attaches, so About and a bug
          // report can never disagree about which build this is.
          const AboutListTile(
            applicationName: 'The Walk Culture',
            applicationVersion: kAppVersion,
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
