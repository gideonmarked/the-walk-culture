import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';
import '../../widgets/sprite_thumb.dart';
import '../spheres/spheres_screen.dart' show kRarityColor;

/// Desaturates locked items so they read as "not collected yet".
const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

const List<ItemSlot> _collectionOrder = [
  ItemSlot.base,
  ItemSlot.hair,
  ItemSlot.face,
  ItemSlot.top,
  ItemSlot.bottom,
  ItemSlot.shoes,
  ItemSlot.hat,
  ItemSlot.accessory,
  ItemSlot.pet,
  ItemSlot.home,
];

/// A "collect them all" gallery of every cosmetic — owned in colour, locked
/// items greyed out. Fed by the Shop and Mystery Spheres.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(playerControllerProvider).owned;
    final total = kShopCatalog.length;
    final have = kShopCatalog.where((i) => owned.contains(i.id)).length;
    final pct = total == 0 ? 0 : (have * 100 / total).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('$have / $total collected  ·  $pct%',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: total == 0 ? 0 : have / total, minHeight: 8),
                  ),
                ],
              ),
            ),
          ),
          for (final slot in _collectionOrder)
            _CategoryBlock(
              slot: slot,
              items: kShopCatalog.where((i) => i.slot == slot).toList(),
              owned: owned,
            ),
        ],
      ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock(
      {required this.slot, required this.items, required this.owned});

  final ItemSlot slot;
  final List<ShopItem> items;
  final Set<String> owned;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final have = items.where((i) => owned.contains(i.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('${slot.label}  ($have/${items.length})',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _CollectionTile(item: item, owned: owned.contains(item.id)),
          ],
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.item, required this.owned});

  final ShopItem item;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final rarityColor = kRarityColor[item.rarity] ?? Colors.grey;
    return Container(
      width: 80,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: owned ? rarityColor : Theme.of(context).dividerColor,
          width: owned ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              owned
                  ? SpriteThumb(item: item, size: 44)
                  : ColorFiltered(
                      colorFilter: _greyscale,
                      child: Opacity(
                          opacity: 0.45,
                          child: SpriteThumb(item: item, size: 44)),
                    ),
              if (!owned)
                const Icon(Icons.lock, size: 18, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 4),
          Text(owned ? item.name : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
