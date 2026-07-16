import '../models/shop_item.dart';

/// Mystery Spheres — the "egg hatching" progression track (doc §6), earned by
/// accumulating steps. Each tier has a base rarity and a small, transparent
/// chance to roll higher. Celestial is real-money only (guaranteed, never a
/// random paid box — keeps us clear of loot-box rules, doc §9).
class SphereTier {
  final String id;
  final String name;
  final String emoji;

  /// Steps needed to open one. -1 means real-money only (Celestial).
  final int stepCost;
  final Rarity baseRarity;

  /// Outcome odds in percent; must sum to 100.
  final Map<Rarity, double> odds;

  const SphereTier({
    required this.id,
    required this.name,
    required this.emoji,
    required this.stepCost,
    required this.baseRarity,
    required this.odds,
  });

  bool get isRealMoney => stepCost < 0;
}

const List<SphereTier> kSphereTiers = [
  SphereTier(
    id: 'bronze', name: 'Bronze Sphere', emoji: '🟤', stepCost: 3000,
    baseRarity: Rarity.common,
    odds: {Rarity.common: 90.0, Rarity.uncommon: 8.0, Rarity.rare: 1.6, Rarity.epic: 0.35, Rarity.legendary: 0.05},
  ),
  SphereTier(
    id: 'silver', name: 'Silver Sphere', emoji: '⚪', stepCost: 5000,
    baseRarity: Rarity.uncommon,
    odds: {Rarity.uncommon: 91.0, Rarity.rare: 7.0, Rarity.epic: 1.7, Rarity.legendary: 0.3},
  ),
  SphereTier(
    id: 'gold', name: 'Gold Sphere', emoji: '🟡', stepCost: 10000,
    baseRarity: Rarity.rare,
    odds: {Rarity.rare: 93.0, Rarity.epic: 6.0, Rarity.legendary: 1.0},
  ),
  SphereTier(
    id: 'platinum', name: 'Platinum Sphere', emoji: '⬜', stepCost: 16000,
    baseRarity: Rarity.epic,
    odds: {Rarity.epic: 95.0, Rarity.legendary: 5.0},
  ),
  SphereTier(
    id: 'diamond', name: 'Diamond Sphere', emoji: '💎', stepCost: 21000,
    baseRarity: Rarity.legendary,
    odds: {Rarity.legendary: 100.0},
  ),
  SphereTier(
    id: 'mythic', name: 'Mythic Sphere', emoji: '🔮', stepCost: 50000,
    baseRarity: Rarity.legendary,
    odds: {Rarity.legendary: 100.0},
  ),
  SphereTier(
    id: 'celestial', name: 'Celestial Sphere', emoji: '🌌', stepCost: -1,
    baseRarity: Rarity.celestial,
    odds: {Rarity.celestial: 100.0},
  ),
];

const List<Rarity> kRarityOrder = [
  Rarity.common,
  Rarity.uncommon,
  Rarity.rare,
  Rarity.epic,
  Rarity.legendary,
  Rarity.celestial,
];

/// Roll a rarity for [tier] given a uniform [roll] in [0, 1). Pure/testable.
Rarity rollSphereRarity(SphereTier tier, double roll) {
  final pct = (roll.clamp(0.0, 0.9999999)) * 100.0;
  var cumulative = 0.0;
  for (final rarity in kRarityOrder) {
    final weight = tier.odds[rarity];
    if (weight == null) continue;
    cumulative += weight;
    if (pct < cumulative) return rarity;
  }
  return tier.baseRarity; // fallback for float rounding
}

/// Result of opening a sphere: either a cosmetic item, or a currency bonus if
/// the player already owns everything of that rarity.
class SphereResult {
  final Rarity rarity;
  final ShopItem? item; // null when granted as currency instead
  final int bonusSteps; // 0 when an item was granted
  const SphereResult({required this.rarity, this.item, this.bonusSteps = 0});
}

/// A sphere's payout, flattened to a string so it can ride along in the
/// persisted player state: 'item:<id>' for a cosmetic, 'steps:<n>' for the
/// currency fallback. Decoded by [decodeSphereReward].
String encodeSphereReward(SphereResult result) => result.item != null
    ? 'item:${result.item!.id}'
    : 'steps:${result.bonusSteps}';

/// The item id and bonus steps behind an [encodeSphereReward] string. Exactly
/// one is meaningful: an unknown or malformed code yields both null/0.
({String? itemId, int bonusSteps}) decodeSphereReward(String code) {
  if (code.startsWith('item:')) {
    return (itemId: code.substring(5), bonusSteps: 0);
  }
  if (code.startsWith('steps:')) {
    return (itemId: null, bonusSteps: int.tryParse(code.substring(6)) ?? 0);
  }
  return (itemId: null, bonusSteps: 0);
}

/// Whether the sphere at [i] should be offered yet: the chain is strictly
/// sequential, so a tier appears only once the one before it has been OPENED —
/// reaching its step cost is not enough. Opened tiers drop out of the list
/// entirely (they move to the day's summary). Real-money tiers always show.
bool sphereVisible(List<SphereTier> tiers, int i, Set<String> opened) {
  final tier = tiers[i];
  if (tier.isRealMoney) return true;
  if (opened.contains(tier.id)) return false;
  if (i == 0) return true;
  final prev = tiers[i - 1];
  return !prev.isRealMoney && opened.contains(prev.id);
}

/// Currency granted when there's no unowned item of the rolled rarity.
int fallbackBonusFor(Rarity rarity) {
  switch (rarity) {
    case Rarity.common:
      return 500;
    case Rarity.uncommon:
      return 2000;
    case Rarity.rare:
      return 10000;
    case Rarity.epic:
      return 50000;
    case Rarity.legendary:
      return 200000;
    case Rarity.celestial:
      return 1000000;
  }
}
