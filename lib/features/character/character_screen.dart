import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';
import '../../widgets/sprite_thumb.dart';
import 'character_profile.dart';

/// Avatar customiser (a tab inside Profile): the layered character up top, then
/// owned items grouped by slot (Body, Hair, Face, Top, …) with equip/unequip.
class AvatarTab extends ConsumerWidget {
  const AvatarTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    List<ShopItem> ownedIn(ItemSlot slot) => kShopCatalog
        .where((i) => i.slot == slot && player.owned.contains(i.id))
        .toList();

    return ListView(
      children: [
        const SizedBox(height: 16),
        const Center(child: CharacterProfile(size: 240)),
        const SizedBox(height: 12),
        for (final slot in kCharacterSlots)
          if (ownedIn(slot).isNotEmpty)
            _SlotSection(
              slot: slot,
              items: ownedIn(slot),
              equippedId: player.equipped[slot],
              onEquip: controller.equip,
              onUnequip: () => controller.unequip(slot),
            ),
        if (kCharacterSlots.every((s) => ownedIn(s).isEmpty))
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No character items yet.\nBuy hair, clothes and accessories in the Shop.',
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.slot,
    required this.items,
    required this.equippedId,
    required this.onEquip,
    required this.onUnequip,
  });

  final ItemSlot slot;
  final List<ShopItem> items;
  final String? equippedId;
  final void Function(ShopItem) onEquip;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(slot.label, style: Theme.of(context).textTheme.titleMedium),
              if (equippedId != null)
                TextButton(onPressed: onUnequip, child: const Text('Unequip')),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ItemChip(
                    item: item,
                    selected: equippedId == item.id,
                    onTap: () => onEquip(item),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip(
      {required this.item, required this.selected, required this.onTap});

  final ShopItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpriteThumb(item: item, size: 44),
            const SizedBox(height: 4),
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
