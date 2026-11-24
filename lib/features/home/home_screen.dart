import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_flags.dart';
import '../../state/app_providers.dart';
import '../../state/notifications.dart';
import '../../state/premium_providers.dart';
import '../../widgets/tier_up_dialog.dart';
import '../bible/bible_screen.dart';
import '../gratitude/gratitude_screen.dart';
import '../notifications/notifications_screen.dart';
import '../prayer/prayer_screen.dart';
import '../prayer_requests/prayer_requests_screen.dart';
import '../prayer_walk/prayer_walk_screen.dart';
import '../quests/quests_screen.dart';
import '../character/character_profile.dart';
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
    // Watched so the devotion buttons below (read off the controller) rebuild
    // as the day's state changes.
    ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final syncOn = ref.watch(healthSyncProvider);
    final isVip = ref.watch(premiumControllerProvider).isVip;
    final bibleReady = controller.bibleReadyToday;
    final prayerReady = controller.prayerReadyToday;
    final prayerWalkReady = controller.prayerWalkReadyToday;
    final gratitudeReady = controller.gratitudeReadyToday;

    // Celebrate the moment the player reaches a new currency tier (doc §6).
    ref.listen<String?>(tierUpProvider, (previous, next) {
      if (next != null) {
        showTierUpDialog(context, next);
        ref.read(tierUpProvider.notifier).state = null;
      }
    });

    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      // No title: the top bar is navigation only. Quests and the Store (shop +
      // VIP) live here; Collection and the Trophy Room moved into the House
      // under Profile, and syncing is a pull-down on the page itself.
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Quests',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuestsScreen()),
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
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
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        // Drag down to pull today's steps from Health. With the dev "walking
        // count" switch off, there's nothing to pull, so it just settles.
        child: RefreshIndicator(
          onRefresh: () async {
            if (syncOn) await controller.syncSteps();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                    child: CharacterProfile(size: 288)), // 96 stage × 3
                const SizedBox(height: 16),
                const HealthCard(),
                const SizedBox(height: 16),
                const BoostCard(),
                const SizedBox(height: 16),
                Text('Wallet', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const WalletBar(),
                const SizedBox(height: 24),
                // Developer tools — mint currency, freeze the health sync, reset
                // today's steps. Gated by kDevToolsEnabled: present in debug and
                // in DEV_TOOLS release builds, compiled OUT of a public release
                // (they'd gut the IAP economy and fake the health ladder).
                if (kDevToolsEnabled) ...[
                  Card(
                    child: SwitchListTile(
                      secondary:
                          Icon(syncOn ? Icons.sync : Icons.sync_disabled),
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
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrayerScreen()),
                  ),
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: Text(prayerReady
                      ? 'Pray for someone'
                      : 'Pray for someone (reward claimed)'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrayerWalkScreen()),
                  ),
                  icon: const Icon(Icons.directions_walk_outlined),
                  label: Text(prayerWalkReady
                      ? 'Prayer walk'
                      : 'Prayer walk (reward claimed)'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GratitudeScreen()),
                  ),
                  icon: const Icon(Icons.favorite_border),
                  label: Text(gratitudeReady
                      ? 'Gratitude journal'
                      : 'Gratitude journal (reward claimed)'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrayerRequestsScreen()),
                  ),
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('Prayer requests'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
