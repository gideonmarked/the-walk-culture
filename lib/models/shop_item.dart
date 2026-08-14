import '../core/currency.dart';

/// Character + world slots. Order here is also the render/layer order (back to
/// front) used by the character profile — see [kSlotZ].
enum ItemSlot { base, bottom, top, shoes, face, hair, hat, accessory, pet, home }

extension ItemSlotLabel on ItemSlot {
  String get label => switch (this) {
        ItemSlot.base => 'Body',
        ItemSlot.bottom => 'Bottom',
        ItemSlot.top => 'Top',
        ItemSlot.shoes => 'Shoes',
        ItemSlot.face => 'Face',
        ItemSlot.hair => 'Hair',
        ItemSlot.hat => 'Hat',
        ItemSlot.accessory => 'Accessory',
        ItemSlot.pet => 'Pet',
        ItemSlot.home => 'Home',
      };

  /// Folder under assets/ where this slot's sprites live.
  String get assetFolder => switch (this) {
        ItemSlot.base => 'character/base',
        ItemSlot.bottom => 'character/bottoms',
        ItemSlot.top => 'character/tops',
        ItemSlot.shoes => 'character/shoes',
        ItemSlot.face => 'character/face',
        ItemSlot.hair => 'character/hair',
        ItemSlot.hat => 'character/hats',
        ItemSlot.accessory => 'character/accessories',
        ItemSlot.pet => 'pets',
        ItemSlot.home => 'home',
      };
}

/// Slots that make up the layered character (excludes home). Ordered back→front.
const List<ItemSlot> kCharacterSlots = [
  ItemSlot.base,
  ItemSlot.bottom,
  ItemSlot.top,
  ItemSlot.shoes,
  ItemSlot.face,
  ItemSlot.hair,
  ItemSlot.hat,
  ItemSlot.accessory,
  ItemSlot.pet,
];

enum Rarity { common, uncommon, rare, epic, legendary, celestial }

/// The wallet tier each rarity is priced in BY DEFAULT. Rarer cosmetics are
/// denominated in a higher currency, so you can't buy an Epic until you've
/// actually banked Gold. Prestige items override this to sit even higher on the
/// ladder (Titanium → Diamond) — see [_kPrestige] in the catalog.
const Map<Rarity, String> kRarityTier = {
  Rarity.common: 'Pebbles',
  Rarity.uncommon: 'Copper',
  Rarity.rare: 'Silver',
  Rarity.epic: 'Gold',
  Rarity.legendary: 'Titanium',
  Rarity.celestial: 'Platinum',
};

/// Whether [spendableSteps] has reached wallet [tier] — the gate that keeps a
/// high-tier item off the shelves until you've banked that currency.
bool walletTierReached(String tier, int spendableSteps) {
  final required = kTierNames.indexOf(tier);
  if (required <= 0) return true; // Steps (or unknown) needs nothing.
  return highestTierIndex(spendableSteps) >= required;
}

/// Whether [spendableSteps] has reached the tier [rarity] is priced in by
/// default. Kept for the standard (non-prestige) catalog and its tests.
bool rarityTierUnlocked(Rarity rarity, int spendableSteps) =>
    walletTierReached(kRarityTier[rarity]!, spendableSteps);

/// The **character sheet**: 64x64 — the size the base art is authored at (see
/// `assets/character/base/tones.json`, `sourceSize` 64x64). The base body and
/// everything worn on it (tops, hair, hats, shoes…) uses this size and stacks
/// paper-doll style, so every layer shares one skeleton.
const double kCanvas = 64;

/// The **stage**: the wider scene the character stands in. Props that aren't
/// *on* the body — a pet trotting alongside, a bag dropped on the floor, wings
/// — are authored at this size so they have room beside the figure.
const double kStage = 96;

/// Top-left of the 64x64 character box inside the stage. Centred horizontally,
/// pushed down so there's headroom above the head for tall hats / flying pets.
const double kCharOriginX = (kStage - kCanvas) / 2; // 16
const double kCharOriginY = 24;

/// The floor line in stage coords — the character's feet rest here, and so does
/// anything standing on the ground next to them. Leaves 8px of floor below.
const double kGroundY = kCharOriginY + kCanvas; // 88

/// Slots authored on the full [kStage] canvas instead of the character sheet.
/// A single item can opt in/out with [ShopItem.stageSpace].
const Set<ItemSlot> kStageSlots = {ItemSlot.pet};

/// A cosmetic. Price is {tier, amount} (doc §7/§8). [x]/[y] fix its position —
/// in stage coords when [onStage], otherwise on the 64px character sheet —
/// and placement is fixed (items never move once bought). [emoji] is only a
/// fallback until real art is dropped into [asset].
class ShopItem {
  final String id;
  final String name;
  final String emoji; // fallback art until the real sprite is added
  final ItemSlot slot;
  final Rarity rarity;
  final String priceTier;
  final int priceAmount;
  final double x; // fixed top-left position in this sprite's own space
  final double y;
  final double w; // sprite size; 0 = a full frame (64 sheet / 96 stage)
  final double h;
  final bool? stageSpace; // override kStageSlots for one item (wings, aura…)
  final bool inShop;

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slot,
    required this.rarity,
    required this.priceTier,
    required this.priceAmount,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
    this.stageSpace,
    this.inShop = true,
  });

  /// Path to the sprite. Replace the file to swap in real art.
  String get asset => 'assets/${slot.assetFolder}/$id.png';

  /// This sprite is placed in stage space (beside the figure) rather than on
  /// the 64px character sheet (worn on the figure).
  bool get onStage => stageSpace ?? kStageSlots.contains(slot);

  /// A tight prop authored at its own size instead of a full frame.
  bool get isTight => w > 0 && h > 0;

  /// Frame size in canvas px: its own [w]/[h] when tight, else the full square.
  double get frameW => isTight ? w : (onStage ? kStage : kCanvas);
  double get frameH => isTight ? h : (onStage ? kStage : kCanvas);

  /// Top-left in **stage** coords — character-sheet sprites get offset by the
  /// character box origin so both spaces composite in one pass.
  double get stageX => (onStage ? 0 : kCharOriginX) + x;
  double get stageY => (onStage ? 0 : kCharOriginY) + y;

  int get costInSteps => priceInSteps(priceTier, priceAmount);

  /// The wallet tier you must have reached to buy this — the tier it's priced in.
  String get requiredTier => priceTier;

  /// The player has banked enough currency to reach this item's tier.
  bool tierUnlocked(int spendableSteps) =>
      walletTierReached(priceTier, spendableSteps);

  /// Reached the tier AND has enough to cover the price.
  bool purchasable(int spendableSteps) =>
      tierUnlocked(spendableSteps) && spendableSteps >= costInSteps;
}
