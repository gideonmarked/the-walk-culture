import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/achievements_catalog.dart';
import '../../data/shop_catalog.dart';
import '../../state/app_providers.dart';
import '../achievements/achievements_screen.dart';
import '../collection/collection_screen.dart';

/// The House tab inside Profile: the player's rooms. The Closet (every
/// cosmetic, owned or not) and the Trophy Room live here; the living room
/// itself isn't built yet.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final owned = kShopCatalog.where((i) => player.owned.contains(i.id)).length;
    final trophies = kAchievements.where((a) => a.unlocked(player)).length;

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _RoomCard(
          emoji: '👕',
          name: 'Closet',
          detail: '$owned / ${kShopCatalog.length} items collected',
          onTap: () => open(const CollectionScreen()),
        ),
        _RoomCard(
          emoji: '🏆',
          name: 'Trophy Room',
          detail: '$trophies / ${kAchievements.length} trophies earned',
          onTap: () => open(const AchievementsScreen()),
        ),
        const _RoomCard(
          emoji: '🛋️',
          name: 'Living Room',
          detail: 'Under construction — decorating your home is coming soon',
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.emoji,
    required this.name,
    required this.detail,
    this.onTap,
  });

  final String emoji;
  final String name;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(emoji, style: const TextStyle(fontSize: 36)),
        title: Text(name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(detail),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
