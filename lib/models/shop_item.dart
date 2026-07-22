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

  /// Folder under assets/ where this slot's 64x64 sprites live.
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

/// Logical pixel-art canvas size. All character sprites are authored at this
/// size (64x64) and composited on a [kCanvas]x[kCanvas] grid. Item [x]/[y] are
/// top-left offsets in this space — placement is fixed (items don't move once
/// bought/placed).
const double kCanvas = 64;

/// A cosmetic. Price is {tier, amount} (doc §7/§8). [x]/[y] fix its position on
/// the character/home canvas; [emoji] is only a fallback until real art is
/// dropped into [asset].
class ShopItem {
  final String id;
  final String name;
  final String emoji; // fallback art until the 64x64 sprite is added
  final ItemSlot slot;
  final Rarity rarity;
  final String priceTier;
  final int priceAmount;
  final double x; // fixed top-left position on the 64px canvas
  final double y;
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
    this.inShop = true,
  });

  /// Path to the 64x64 sprite. Replace the file to swap in real art.
  String get asset => 'assets/${slot.assetFolder}/$id.png';

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
