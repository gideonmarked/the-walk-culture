import 'package:flutter_test/flutter_test.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/shop_item.dart';

/// The compositor draws everything in stage coordinates, so the two spaces
/// (64px character sheet, 96px stage) have to agree on where the character box
/// and the ground line are — see docs/PIXEL_ART_GUIDE.md §2b.
void main() {
  test('the character box is centred in the stage and sits on the ground line',
      () {
    expect(kCharOriginX, (kStage - kCanvas) / 2);
    expect(kCharOriginX + kCanvas, kStage - kCharOriginX); // equal gutters
    expect(kGroundY, kCharOriginY + kCanvas);
    expect(kGroundY, lessThanOrEqualTo(kStage)); // floor strip, never overflow
  });

  test('worn sprites are offset into the stage, stage props are not', () {
    const hoodie = ShopItem(
      id: 'top_x',
      name: 'X',
      emoji: '👕',
      slot: ItemSlot.top,
      rarity: Rarity.common,
      priceTier: 'Pebbles',
      priceAmount: 1,
    );
    expect(hoodie.onStage, isFalse);
    expect(hoodie.stageX, kCharOriginX);
    expect(hoodie.stageY, kCharOriginY);
    expect(hoodie.frameW, kCanvas);

    const dog = ShopItem(
      id: 'pet_x',
      name: 'X',
      emoji: '🐶',
      slot: ItemSlot.pet,
      rarity: Rarity.common,
      priceTier: 'Pebbles',
      priceAmount: 1,
      x: 66,
      y: 70,
      w: 22,
      h: 18,
    );
    expect(dog.onStage, isTrue);
    expect(dog.isTight, isTrue);
    expect(dog.stageX, 66); // stage coords used as-is
    expect(dog.stageY, 70);
    expect(dog.stageY + dog.frameH, kGroundY); // standing on the floor
  });

  test('an accessory can opt into stage space (wings, auras)', () {
    const wings = ShopItem(
      id: 'acc_wings',
      name: 'Wings',
      emoji: '🪽',
      slot: ItemSlot.accessory,
      rarity: Rarity.epic,
      priceTier: 'Gold',
      priceAmount: 1,
      stageSpace: true,
    );
    expect(wings.onStage, isTrue);
    expect(wings.stageX, 0);
    expect(wings.frameW, kStage);
  });

  test('every catalog sprite stays inside its canvas', () {
    for (final item in kShopCatalog) {
      final limit = item.onStage ? kStage : kCanvas;
      expect(item.x + item.frameW, lessThanOrEqualTo(limit), reason: item.id);
      expect(item.y + item.frameH, lessThanOrEqualTo(limit), reason: item.id);
    }
  });
}
