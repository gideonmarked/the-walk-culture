import '../models/shop_item.dart';

/// Hand-authored seed catalog. Emoji are placeholders — drop a 64x64 PNG at
/// each item's [ShopItem.asset] path to replace it (see docs/ASSETS.md).
/// Character items come first (prioritised), then pets and home. x/y default to
/// 0 (full-frame sprites); set them to nudge small elements to a fixed spot.
///
/// The full shop is this seed plus a large generated set — see [kShopCatalog].
const List<ShopItem> _kSeedCatalog = [
  // ============================ CHARACTER ============================

  // --- Body / skin tone (base layer) ---
  ShopItem(id: 'base_light', name: 'Light Skin', emoji: '🧑🏻', slot: ItemSlot.base, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 100),
  ShopItem(id: 'base_fair', name: 'Fair Skin', emoji: '🧑🏼', slot: ItemSlot.base, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 100),
  ShopItem(id: 'base_medium', name: 'Medium Skin', emoji: '🧑🏽', slot: ItemSlot.base, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 100),
  ShopItem(id: 'base_brown', name: 'Brown Skin', emoji: '🧑🏾', slot: ItemSlot.base, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 100),
  ShopItem(id: 'base_dark', name: 'Dark Skin', emoji: '🧑🏿', slot: ItemSlot.base, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 100),

  // --- Face ---
  ShopItem(id: 'face_smile', name: 'Smile', emoji: '🙂', slot: ItemSlot.face, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 200),
  ShopItem(id: 'face_grin', name: 'Big Grin', emoji: '😄', slot: ItemSlot.face, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 200),
  ShopItem(id: 'face_wink', name: 'Wink', emoji: '😉', slot: ItemSlot.face, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 10),
  ShopItem(id: 'face_cool', name: 'Cool', emoji: '😎', slot: ItemSlot.face, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 20),
  ShopItem(id: 'face_freckles', name: 'Freckles', emoji: '😊', slot: ItemSlot.face, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),

  // --- Hair ---
  ShopItem(id: 'hair_short', name: 'Short Hair', emoji: '👦', slot: ItemSlot.hair, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 300),
  ShopItem(id: 'hair_buzz', name: 'Buzz Cut', emoji: '🧑‍🦲', slot: ItemSlot.hair, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 300),
  ShopItem(id: 'hair_long', name: 'Long Hair', emoji: '👩', slot: ItemSlot.hair, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 400),
  ShopItem(id: 'hair_curly', name: 'Curly Hair', emoji: '👩‍🦱', slot: ItemSlot.hair, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 20),
  ShopItem(id: 'hair_redhead', name: 'Redhead', emoji: '👩‍🦰', slot: ItemSlot.hair, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 20),
  ShopItem(id: 'hair_ponytail', name: 'Ponytail', emoji: '👱‍♀️', slot: ItemSlot.hair, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 30),
  ShopItem(id: 'hair_afro', name: 'Afro', emoji: '🧑‍🦱', slot: ItemSlot.hair, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),
  ShopItem(id: 'hair_silver', name: 'Silver Hair', emoji: '👩‍🦳', slot: ItemSlot.hair, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),
  ShopItem(id: 'hair_mohawk', name: 'Mohawk', emoji: '🧑‍🎤', slot: ItemSlot.hair, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),
  ShopItem(id: 'hair_rainbow', name: 'Rainbow Hair', emoji: '🌈', slot: ItemSlot.hair, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 1),

  // --- Tops ---
  ShopItem(id: 'top_tee', name: 'Athletic Tee', emoji: '👕', slot: ItemSlot.top, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 400),
  ShopItem(id: 'top_tank', name: 'Tank Top', emoji: '🎽', slot: ItemSlot.top, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 500),
  ShopItem(id: 'top_blouse', name: 'Blouse', emoji: '👚', slot: ItemSlot.top, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 30),
  ShopItem(id: 'top_hoodie', name: 'Hoodie', emoji: '🥋', slot: ItemSlot.top, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 60),
  ShopItem(id: 'top_coat', name: 'Winter Coat', emoji: '🧥', slot: ItemSlot.top, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),
  ShopItem(id: 'top_kimono', name: 'Kimono', emoji: '🥻', slot: ItemSlot.top, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 2),

  // --- Bottoms ---
  ShopItem(id: 'bottom_shorts', name: 'Running Shorts', emoji: '🩳', slot: ItemSlot.bottom, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 400),
  ShopItem(id: 'bottom_jeans', name: 'Jeans', emoji: '👖', slot: ItemSlot.bottom, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 600),
  ShopItem(id: 'bottom_skirt', name: 'Skirt', emoji: '👗', slot: ItemSlot.bottom, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 30),
  ShopItem(id: 'bottom_cargo', name: 'Cargo Pants', emoji: '🧵', slot: ItemSlot.bottom, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),

  // --- Shoes ---
  ShopItem(id: 'shoes_run', name: 'Running Shoes', emoji: '👟', slot: ItemSlot.shoes, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 500),
  ShopItem(id: 'shoes_sandal', name: 'Sandals', emoji: '🩴', slot: ItemSlot.shoes, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 500),
  ShopItem(id: 'shoes_boot', name: 'Hiking Boots', emoji: '🥾', slot: ItemSlot.shoes, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 40),
  ShopItem(id: 'shoes_heels', name: 'Party Heels', emoji: '👠', slot: ItemSlot.shoes, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 2),

  // --- Hats ---
  ShopItem(id: 'hat_cap', name: 'Runner Cap', emoji: '🧢', slot: ItemSlot.hat, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 500),
  ShopItem(id: 'hat_beanie', name: 'Cozy Beanie', emoji: '🧶', slot: ItemSlot.hat, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 900),
  ShopItem(id: 'hat_straw', name: 'Straw Hat', emoji: '👒', slot: ItemSlot.hat, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 30),
  ShopItem(id: 'hat_top', name: 'Top Hat', emoji: '🎩', slot: ItemSlot.hat, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 50),
  ShopItem(id: 'hat_grad', name: 'Graduation Cap', emoji: '🎓', slot: ItemSlot.hat, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 2),
  ShopItem(id: 'hat_crown', name: 'Golden Crown', emoji: '👑', slot: ItemSlot.hat, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 2),

  // --- Accessories ---
  ShopItem(id: 'acc_glasses', name: 'Cool Shades', emoji: '🕶️', slot: ItemSlot.accessory, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 20),
  ShopItem(id: 'acc_specs', name: 'Round Glasses', emoji: '👓', slot: ItemSlot.accessory, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 20),
  ShopItem(id: 'acc_scarf', name: 'Scarf', emoji: '🧣', slot: ItemSlot.accessory, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 40),
  ShopItem(id: 'acc_backpack', name: 'Day Pack', emoji: '🎒', slot: ItemSlot.accessory, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),
  ShopItem(id: 'acc_watch', name: 'Fitness Watch', emoji: '⌚', slot: ItemSlot.accessory, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 3),
  ShopItem(id: 'acc_necklace', name: 'Gold Chain', emoji: '📿', slot: ItemSlot.accessory, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 1),

  // ============================== PETS ==============================
  ShopItem(id: 'pet_dog', name: 'Puppy', emoji: '🐶', slot: ItemSlot.pet, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 50),
  ShopItem(id: 'pet_cat', name: 'Kitten', emoji: '🐱', slot: ItemSlot.pet, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 50),
  ShopItem(id: 'pet_bunny', name: 'Bunny', emoji: '🐰', slot: ItemSlot.pet, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 2),
  ShopItem(id: 'pet_fox', name: 'Fox', emoji: '🦊', slot: ItemSlot.pet, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 2),
  ShopItem(id: 'pet_dragon', name: 'Baby Dragon', emoji: '🐲', slot: ItemSlot.pet, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1, inShop: false),

  // ============================== HOME ==============================
  ShopItem(id: 'home_plant', name: 'Potted Plant', emoji: '🪴', slot: ItemSlot.home, rarity: Rarity.common, priceTier: 'Pebbles', priceAmount: 400),
  ShopItem(id: 'home_rug', name: 'Area Rug', emoji: '🟫', slot: ItemSlot.home, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 30),
  ShopItem(id: 'home_lamp', name: 'Cozy Lamp', emoji: '🪔', slot: ItemSlot.home, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 50),
  ShopItem(id: 'home_clock', name: 'Wall Clock', emoji: '🕰️', slot: ItemSlot.home, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 1),
  ShopItem(id: 'home_aquarium', name: 'Aquarium', emoji: '🐠', slot: ItemSlot.home, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 1),

  // ==================== REWARD-ONLY (Mystery Spheres) ====================
  ShopItem(id: 'acc_wings', name: 'Aurora Wings', emoji: '🪽', slot: ItemSlot.accessory, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1, inShop: false),
  ShopItem(id: 'home_fountain', name: 'Crystal Fountain', emoji: '⛲', slot: ItemSlot.home, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1, inShop: false),
  ShopItem(id: 'top_phoenix', name: 'Phoenix Robe', emoji: '🔥', slot: ItemSlot.top, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1, inShop: false),
  ShopItem(id: 'hat_antlers', name: 'Mystic Antlers', emoji: '🦌', slot: ItemSlot.hat, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1, inShop: false),
  ShopItem(id: 'hair_galaxy', name: 'Galaxy Hair', emoji: '🌌', slot: ItemSlot.hair, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1, inShop: false),
  ShopItem(id: 'acc_halo', name: 'Celestial Halo', emoji: '😇', slot: ItemSlot.accessory, rarity: Rarity.celestial, priceTier: 'Platinum', priceAmount: 0, inShop: false),
  ShopItem(id: 'top_starcloak', name: 'Starlit Cloak', emoji: '🌟', slot: ItemSlot.top, rarity: Rarity.celestial, priceTier: 'Platinum', priceAmount: 0, inShop: false),
];

/// One garment/pet/decor "style" the generator makes colour variants of.
class _Style {
  const _Style(this.slot, this.noun, this.emoji);
  final ItemSlot slot;
  final String noun;
  final String emoji;
}

/// 50 styles spread across every slot. Each becomes 10 colour variants below,
/// giving 500 generated shop items on top of the hand-authored seed.
const List<_Style> _kStyles = [
  // Tops (8)
  _Style(ItemSlot.top, 'Tee', '👕'),
  _Style(ItemSlot.top, 'Tank', '🎽'),
  _Style(ItemSlot.top, 'Hoodie', '🧥'),
  _Style(ItemSlot.top, 'Jacket', '🧥'),
  _Style(ItemSlot.top, 'Sweater', '🧶'),
  _Style(ItemSlot.top, 'Polo', '👕'),
  _Style(ItemSlot.top, 'Jersey', '🎽'),
  _Style(ItemSlot.top, 'Windbreaker', '🧥'),
  // Bottoms (6)
  _Style(ItemSlot.bottom, 'Shorts', '🩳'),
  _Style(ItemSlot.bottom, 'Jeans', '👖'),
  _Style(ItemSlot.bottom, 'Joggers', '👖'),
  _Style(ItemSlot.bottom, 'Skirt', '👗'),
  _Style(ItemSlot.bottom, 'Leggings', '👖'),
  _Style(ItemSlot.bottom, 'Cargos', '🧵'),
  // Shoes (6)
  _Style(ItemSlot.shoes, 'Sneakers', '👟'),
  _Style(ItemSlot.shoes, 'Boots', '🥾'),
  _Style(ItemSlot.shoes, 'Sandals', '🩴'),
  _Style(ItemSlot.shoes, 'Heels', '👠'),
  _Style(ItemSlot.shoes, 'Loafers', '🥿'),
  _Style(ItemSlot.shoes, 'Cleats', '👟'),
  // Hats (6)
  _Style(ItemSlot.hat, 'Cap', '🧢'),
  _Style(ItemSlot.hat, 'Beanie', '🧶'),
  _Style(ItemSlot.hat, 'Fedora', '🎩'),
  _Style(ItemSlot.hat, 'Sunhat', '👒'),
  _Style(ItemSlot.hat, 'Visor', '🧢'),
  _Style(ItemSlot.hat, 'Bucket Hat', '🪣'),
  // Accessories (7)
  _Style(ItemSlot.accessory, 'Shades', '🕶️'),
  _Style(ItemSlot.accessory, 'Glasses', '👓'),
  _Style(ItemSlot.accessory, 'Scarf', '🧣'),
  _Style(ItemSlot.accessory, 'Watch', '⌚'),
  _Style(ItemSlot.accessory, 'Gloves', '🧤'),
  _Style(ItemSlot.accessory, 'Belt', '🥋'),
  _Style(ItemSlot.accessory, 'Pendant', '📿'),
  // Hair (6)
  _Style(ItemSlot.hair, 'Bob', '💇'),
  _Style(ItemSlot.hair, 'Braids', '👩‍🦱'),
  _Style(ItemSlot.hair, 'Waves', '👱'),
  _Style(ItemSlot.hair, 'Bun', '👩'),
  _Style(ItemSlot.hair, 'Pixie', '💇‍♀️'),
  _Style(ItemSlot.hair, 'Dreads', '🧑‍🦱'),
  // Face (3)
  _Style(ItemSlot.face, 'Smirk', '😏'),
  _Style(ItemSlot.face, 'Blush', '😊'),
  _Style(ItemSlot.face, 'Focus', '😤'),
  // Pets (4)
  _Style(ItemSlot.pet, 'Hamster', '🐹'),
  _Style(ItemSlot.pet, 'Panda', '🐼'),
  _Style(ItemSlot.pet, 'Owl', '🦉'),
  _Style(ItemSlot.pet, 'Penguin', '🐧'),
  // Home (4)
  _Style(ItemSlot.home, 'Vase', '🏺'),
  _Style(ItemSlot.home, 'Candle', '🕯️'),
  _Style(ItemSlot.home, 'Cactus', '🌵'),
  _Style(ItemSlot.home, 'Painting', '🖼️'),
];

/// Colour themes, ordered plain → premium. Index maps to rarity in [_variantRarity]
/// so a "Golden" item is always rarer (and costlier) than a "Crimson" one.
const List<String> _kVariants = [
  'Crimson',
  'Amber',
  'Emerald',
  'Azure',
  'Violet',
  'Onyx',
  'Ivory',
  'Rose',
  'Slate',
  'Golden',
];

/// Rarity for each variant index — 4 common, 3 uncommon, 2 rare, 1 epic per
/// style. Legendary stays reserved for Mystery Sphere loot, not the shelves.
const List<Rarity> _variantRarity = [
  Rarity.common,
  Rarity.common,
  Rarity.common,
  Rarity.common,
  Rarity.uncommon,
  Rarity.uncommon,
  Rarity.uncommon,
  Rarity.rare,
  Rarity.rare,
  Rarity.epic,
];

String _slug(String s) => s.toLowerCase().replaceAll(' ', '_');

/// Price within the rarity's own tier, nudged by the style so a shelf of the
/// same rarity isn't all one number. Stays inside the tier the gate expects.
int _price(Rarity rarity, int styleIndex) {
  switch (rarity) {
    case Rarity.common:
      return 100 + (styleIndex % 9) * 100; // 100–900 Steps
    case Rarity.uncommon:
      return 10 + (styleIndex % 9) * 10; // 10–90 Copper
    case Rarity.rare:
      return 1 + (styleIndex % 9); // 1–9 Silver
    case Rarity.epic:
      return 1 + (styleIndex % 3); // 1–3 Gold
    case Rarity.legendary:
      return 1;
    case Rarity.celestial:
      return 0;
  }
}

List<ShopItem> _generatedCatalog() {
  final items = <ShopItem>[];
  for (var s = 0; s < _kStyles.length; s++) {
    final style = _kStyles[s];
    for (var v = 0; v < _kVariants.length; v++) {
      final variant = _kVariants[v];
      final rarity = _variantRarity[v];
      items.add(ShopItem(
        id: 'gen_${style.slot.name}_${_slug(style.noun)}_${_slug(variant)}',
        name: '$variant ${style.noun}',
        emoji: style.emoji,
        slot: style.slot,
        rarity: rarity,
        priceTier: kRarityTier[rarity]!,
        priceAmount: _price(rarity, s),
      ));
    }
  }
  return items;
}

/// Prestige line — aspirational cosmetics priced ABOVE Gold, one rung of the
/// currency ladder each: Titanium → Platinum → Tanzanite → Emerald → Ruby →
/// Diamond. The buy gate keys off each item's own [ShopItem.priceTier], so these
/// stay locked until you've banked that currency. Legendary up to Emerald, then
/// Celestial for the very top two. Deliberately steep — these are flex items.
const List<ShopItem> _kPrestige = [
  // Titanium
  ShopItem(id: 'pr_titan_helm', name: 'Titanium Helm', emoji: '🪖', slot: ItemSlot.hat, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 1),
  ShopItem(id: 'pr_chrome_kicks', name: 'Chrome Kicks', emoji: '👟', slot: ItemSlot.shoes, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 2),
  // Platinum
  ShopItem(id: 'pr_plat_crown', name: 'Platinum Crown', emoji: '👑', slot: ItemSlot.hat, rarity: Rarity.legendary, priceTier: 'Platinum', priceAmount: 1),
  ShopItem(id: 'pr_frost_cloak', name: 'Frost Cloak', emoji: '🧊', slot: ItemSlot.top, rarity: Rarity.legendary, priceTier: 'Platinum', priceAmount: 2),
  // Tanzanite
  ShopItem(id: 'pr_tanz_wings', name: 'Tanzanite Wings', emoji: '🦋', slot: ItemSlot.accessory, rarity: Rarity.legendary, priceTier: 'Tanzanite', priceAmount: 1),
  ShopItem(id: 'pr_void_hood', name: 'Void Hood', emoji: '🌑', slot: ItemSlot.top, rarity: Rarity.legendary, priceTier: 'Tanzanite', priceAmount: 3),
  // Emerald
  ShopItem(id: 'pr_emerald_charm', name: 'Emerald Charm', emoji: '💚', slot: ItemSlot.accessory, rarity: Rarity.legendary, priceTier: 'Emerald', priceAmount: 1),
  ShopItem(id: 'pr_jade_dragon', name: 'Jade Dragon', emoji: '🐉', slot: ItemSlot.pet, rarity: Rarity.legendary, priceTier: 'Emerald', priceAmount: 2),
  // Ruby
  ShopItem(id: 'pr_ruby_halo', name: 'Ruby Halo', emoji: '😇', slot: ItemSlot.accessory, rarity: Rarity.celestial, priceTier: 'Ruby', priceAmount: 1),
  ShopItem(id: 'pr_inferno_mane', name: 'Inferno Mane', emoji: '🦁', slot: ItemSlot.hair, rarity: Rarity.celestial, priceTier: 'Ruby', priceAmount: 3),
  // Diamond — the top of the ladder
  ShopItem(id: 'pr_diamond_crown', name: 'Diamond Crown', emoji: '💎', slot: ItemSlot.hat, rarity: Rarity.celestial, priceTier: 'Diamond', priceAmount: 1),
  ShopItem(id: 'pr_eternity_cloak', name: 'Eternity Cloak', emoji: '✨', slot: ItemSlot.top, rarity: Rarity.celestial, priceTier: 'Diamond', priceAmount: 2),
];

/// The full shop: hand-authored seed first (curated items lead), then the
/// generated colour variants, then the prestige line above Gold. Computed once.
final List<ShopItem> kShopCatalog = [
  ..._kSeedCatalog,
  ..._generatedCatalog(),
  ..._kPrestige,
];
