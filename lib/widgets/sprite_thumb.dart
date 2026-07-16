import 'package:flutter/material.dart';

import '../models/shop_item.dart';

/// Shows an item's 64x64 sprite, falling back to its emoji until real art is
/// dropped in at [ShopItem.asset].
class SpriteThumb extends StatelessWidget {
  const SpriteThumb({super.key, required this.item, this.size = 40});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      item.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(item.emoji, style: TextStyle(fontSize: size * 0.7)),
        ),
      ),
    );
  }
}
