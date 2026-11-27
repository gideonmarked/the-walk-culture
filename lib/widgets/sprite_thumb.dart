import 'package:flutter/material.dart';

import '../models/shop_item.dart';
import 'pixel_sprite.dart';

/// Shows an item's sprite in its own colours (its first frame), falling back
/// to its emoji until real art is dropped in at [ShopItem.asset] or its shared
/// drawing [ShopItem.sharedAsset].
class SpriteThumb extends StatelessWidget {
  const SpriteThumb({super.key, required this.item, this.size = 40});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PixelSprite(
        item: item,
        recipe: item.colors,
        fallback: Center(
          child: Text(item.emoji, style: TextStyle(fontSize: size * 0.7)),
        ),
      ),
    );
  }
}
