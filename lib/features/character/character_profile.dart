import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';

/// Where a slot's emoji sits while it has no real sprite yet (so the composite
/// still reads sensibly). Real 64x64 art ignores this and uses [ShopItem.x]/[y].
const Map<ItemSlot, Alignment> _fallbackAlign = {
  ItemSlot.base: Alignment.center,
  ItemSlot.bottom: Alignment(0, 0.35),
  ItemSlot.top: Alignment(0, -0.05),
  ItemSlot.shoes: Alignment(0, 0.9),
  ItemSlot.face: Alignment(0, -0.4),
  ItemSlot.hair: Alignment(0, -0.72),
  ItemSlot.hat: Alignment(0, -1.0),
  ItemSlot.accessory: Alignment(0.55, -0.15),
  ItemSlot.pet: Alignment(0.95, 0.95),
};

/// Composites the equipped character sprites (back→front) on a fixed 64px
/// canvas scaled to [size]. Placement is data-driven and not user-movable.
class CharacterProfile extends ConsumerWidget {
  const CharacterProfile({super.key, this.size = 220});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipped = ref.watch(playerControllerProvider).equipped;
    final scale = size / kCanvas;

    ShopItem? itemFor(ItemSlot slot) {
      final id = equipped[slot];
      if (id == null) return null;
      for (final item in kShopCatalog) {
        if (item.id == id) return item;
      }
      return null;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (equipped[ItemSlot.base] == null)
            Center(
              child: Text('🧍', style: TextStyle(fontSize: size * 0.55)),
            ),
          for (final slot in kCharacterSlots)
            if (itemFor(slot) != null)
              _Layer(item: itemFor(slot)!, scale: scale, size: size),
        ],
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({required this.item, required this.scale, required this.size});

  final ShopItem item;
  final double scale;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: item.x * scale,
      top: item.y * scale,
      width: size,
      height: size,
      child: Image.asset(
        item.asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none, // crisp pixel art
        errorBuilder: (_, __, ___) => Align(
          alignment: _fallbackAlign[item.slot] ?? Alignment.center,
          child: Text(item.emoji, style: TextStyle(fontSize: size * 0.18)),
        ),
      ),
    );
  }
}
