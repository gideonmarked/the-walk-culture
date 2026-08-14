import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';

/// Where a slot's emoji sits inside its own frame while it has no real sprite
/// yet (so the composite still reads sensibly). Real art ignores this and uses
/// [ShopItem.x]/[y]. Alignments are frame-relative, so they survive a canvas
/// resize.
const Map<ItemSlot, Alignment> _fallbackAlign = {
  ItemSlot.base: Alignment.center,
  ItemSlot.bottom: Alignment(0, 0.35),
  ItemSlot.top: Alignment(0, -0.05),
  ItemSlot.shoes: Alignment(0, 0.9),
  ItemSlot.face: Alignment(0, -0.4),
  ItemSlot.hair: Alignment(0, -0.72),
  ItemSlot.hat: Alignment(0, -1.0),
  ItemSlot.accessory: Alignment(0.55, -0.15),
  ItemSlot.pet: Alignment(0.8, 0.72), // beside the feet, on the ground line
};

/// Composites the equipped character sprites (back→front) on the [kStage]
/// canvas. The [kCanvas] character box sits centred inside the stage; pets and
/// floor props live in the room around it. Placement is data-driven and not
/// user-movable.
///
/// [size] is a *maximum* — the stage is drawn at the largest whole-number
/// upscale that fits it and the incoming constraints, so nearest-neighbour
/// pixels stay perfectly square (96 → 192 → 288).
class CharacterProfile extends ConsumerWidget {
  const CharacterProfile({super.key, this.size = 288});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var budget = size;
        if (constraints.hasBoundedWidth) {
          budget = math.min(budget, constraints.maxWidth);
        }
        if (constraints.hasBoundedHeight) {
          budget = math.min(budget, constraints.maxHeight);
        }
        final scale = math.max(1, (budget / kStage).floor()).toDouble();
        return _Stage(scale: scale);
      },
    );
  }
}

class _Stage extends ConsumerWidget {
  const _Stage({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipped = ref.watch(playerControllerProvider).equipped;
    final size = kStage * scale;

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
            Positioned(
              left: kCharOriginX * scale,
              top: kCharOriginY * scale,
              width: kCanvas * scale,
              height: kCanvas * scale,
              child: Center(
                child: Text('🧍',
                    style: TextStyle(fontSize: kCanvas * scale * 0.55)),
              ),
            ),
          for (final slot in kCharacterSlots)
            if (itemFor(slot) != null)
              _Layer(item: itemFor(slot)!, scale: scale),
        ],
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({required this.item, required this.scale});

  final ShopItem item;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final w = item.frameW * scale;
    final h = item.frameH * scale;
    // A tight prop fills its own little frame; a full frame is mostly empty, so
    // the emoji is drawn small and parked where that slot belongs.
    final emojiSize = math.min(w, h) * (item.isTight ? 0.9 : 0.27);

    return Positioned(
      left: item.stageX * scale,
      top: item.stageY * scale,
      width: w,
      height: h,
      child: Image.asset(
        item.asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none, // crisp pixel art
        errorBuilder: (_, __, ___) => Align(
          alignment: item.isTight
              ? Alignment.center
              : (_fallbackAlign[item.slot] ?? Alignment.center),
          child: Text(item.emoji, style: TextStyle(fontSize: emojiSize)),
        ),
      ),
    );
  }
}
