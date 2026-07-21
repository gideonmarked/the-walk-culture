import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dev_flags.dart';
import '../../state/app_providers.dart';
import '../../state/premium_providers.dart';
import '../../widgets/tier_up_dialog.dart';
import '../achievements/achievements_screen.dart';
import '../bible/bible_screen.dart';
import '../character/character_profile.dart';
import '../collection/collection_screen.dart';
import '../settings/settings_screen.dart';
import '../store/store_screen.dart';
import '../wallet/wallet_bar.dart';
import 'widgets/boost_card.dart';
import 'widgets/health_card.dart';
import 'widgets/simulate_steps_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final fmt = NumberFormat.decimalPattern();
    final syncOn = ref.watch(healthSyncProvider);
    final isVip = ref.watch(premiumControllerProvider).isVip;
    final bibleReady = controller.bibleReadyToday;

    // Celebrate the moment the player reaches a new currency tier (doc §6).
    ref.listen<String?>(tierUpProvider, (previous, next) {
      if (next != null) {
        showTierUpDialog(context, next);
        ref.read(tierUpProvider.notifier).state = null;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Walk Culture'),
        actions: [
          IconButton(
            tooltip: isVip ? 'Store · VIP active' : 'Store',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StoreScreen()),
            ),
            icon: Icon(
              isVip ? Icons.workspace_premium : Icons.storefront,
              color: isVip ? Colors.amber : null,
            ),
          ),
          IconButton(
            tooltip: 'Collection',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CollectionScreen()),
            ),
            icon: const Icon(Icons.grid_view_outlined),
          ),
          IconButton(
            tooltip: 'Trophy Room',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: syncOn ? 'Sync steps from Health' : 'Health sync is off',
            onPressed: syncOn ? controller.syncSteps : null,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: CharacterProfile(size: 200)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Today',
                          style: Theme.of(context).textTheme.labelMedium),
                      Text('${fmt.format(ref.watch(liveStepsProvider) ?? player.todaySteps)} steps',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const HealthCard(),
              const SizedBox(height: 16),
              const BoostCard(),
              const SizedBox(height: 16),
              Text('Wallet', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const WalletBar(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: syncOn ? controller.syncSteps : null,
                icon: const Icon(Icons.sync),
                label: const Text('Sync steps from Health'),
              ),
              const SizedBox(height: 8),
              // Developer tools — mint currency, freeze the health sync, reset
              // today's steps. Gated by kDevToolsEnabled: present in debug and
              // in DEV_TOOLS release builds, compiled OUT of a public release
              // (they'd gut the IAP economy and fake the health ladder).
              if (kDevToolsEnabled) ...[
                Card(
                  child: SwitchListTile(
                    secondary: Icon(syncOn ? Icons.sync : Icons.sync_disabled),
                    title: const Text('Walking count (dev)'),
                    subtitle: Text(
                      syncOn
                          ? "On — today's count follows your health data"
                          : 'Off — simulated steps stay put',
                    ),
                    value: syncOn,
                    onChanged: (on) =>
                        ref.read(healthSyncProvider.notifier).setEnabled(on),
                  ),
                ),
                const SizedBox(height: 8),
                const SimulateStepsCard(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await controller.resetDailySteps();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                          content: Text(
                              "Today's steps reset — lifetime kept in Statistics"),
                        ));
                    }
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("Reset today's steps (dev)"),
                ),
                const SizedBox(height: 8),
              ],
              Tooltip(
                message:
                    'TURBO (live GPS distance & routes) ships in Phase 4 — see design doc §2.4',
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.bolt),
                  label: const Text('TURBO — coming in Phase 4'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BibleScreen()),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(bibleReady
                    ? "Read today's Bible verse"
                    : "Today's Bible verse (reward claimed)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
