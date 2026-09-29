import 'package:intl/intl.dart';

import '../core/travel_pass.dart';
import '../models/shop_item.dart';

/// The Travel Pass cosmetics — the only place these items ever come from.
///
/// Every one is `inShop: false` (never on the shelves, priced 0 so the
/// server's purchase_item() can't sell it) AND `passExclusive: true`, which
/// keeps it out of [kRollableCatalog] so no sphere or devotion roll can hand it
/// out. Miss either flag and "exclusive" becomes a lie.
///
/// `priceTier` still has to be its rarity's default tier — the shop-gate tests
/// hold every non-prestige item to that, and Collection/Statistics read it.
/// The amount is 0: these are earned, never bought.
const List<ShopItem> kPassCatalog = [
  // ---- Free track (5) — real cosmetics, so a free season still dresses you.
  ShopItem(id: 'pass_trail_cap', name: 'Trail Cap', emoji: '🧢', slot: ItemSlot.hat, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_wayfarer_tee', name: 'Wayfarer Tee', emoji: '👕', slot: ItemSlot.top, rarity: Rarity.uncommon, priceTier: 'Copper', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_dust_boots', name: 'Dust Road Boots', emoji: '🥾', slot: ItemSlot.shoes, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_lantern', name: 'Road Lantern', emoji: '🏮', slot: ItemSlot.home, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_pilgrim_staff', name: 'Pilgrim Staff', emoji: '🦯', slot: ItemSlot.accessory, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 0, inShop: false, passExclusive: true),

  // ---- VIP track (12) — the reason to subscribe. Rarity climbs with the
  // level, topping out at two Celestials in the last two rungs.
  ShopItem(id: 'pass_vip_sash', name: "Traveler's Sash", emoji: '🎗️', slot: ItemSlot.accessory, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_cloak', name: "Cartographer's Cloak", emoji: '🗺️', slot: ItemSlot.top, rarity: Rarity.rare, priceTier: 'Silver', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_compass', name: 'Golden Compass', emoji: '🧭', slot: ItemSlot.accessory, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_hat', name: 'Caravan Hat', emoji: '👒', slot: ItemSlot.hat, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_camel', name: 'Desert Camel', emoji: '🐫', slot: ItemSlot.pet, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_braid', name: 'Horizon Braid', emoji: '💫', slot: ItemSlot.hair, rarity: Rarity.epic, priceTier: 'Gold', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_coat', name: "Wanderer's Coat", emoji: '🧥', slot: ItemSlot.top, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_boots', name: 'Starlit Boots', emoji: '✨', slot: ItemSlot.shoes, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_phoenix', name: 'Trail Phoenix', emoji: '🔥', slot: ItemSlot.pet, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_mantle', name: 'Aurora Mantle', emoji: '🌠', slot: ItemSlot.accessory, rarity: Rarity.legendary, priceTier: 'Titanium', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_crown', name: 'Sunrise Crown', emoji: '👑', slot: ItemSlot.hat, rarity: Rarity.celestial, priceTier: 'Platinum', priceAmount: 0, inShop: false, passExclusive: true),
  ShopItem(id: 'pass_vip_halo', name: "Wayfinder's Halo", emoji: '🌟', slot: ItemSlot.accessory, rarity: Rarity.celestial, priceTier: 'Platinum', priceAmount: 0, inShop: false, passExclusive: true),
];

final Map<String, ShopItem> _byId = {for (final i in kPassCatalog) i.id: i};

/// The cosmetic behind an item reward, or null for Pebbles/boost rewards (and
/// for an id that's been removed from the catalog — the UI degrades to its
/// label rather than crashing on a stale save).
ShopItem? passRewardItem(PassReward reward) =>
    reward.kind == PassRewardKind.item ? _byId[reward.itemId] : null;

/// What the reward is called, for tiles and claim toasts.
String passRewardLabel(PassReward reward) {
  switch (reward.kind) {
    case PassRewardKind.pebbles:
      return '${NumberFormat.decimalPattern().format(reward.amount)} Pebbles';
    case PassRewardKind.item:
      return passRewardItem(reward)?.name ?? 'Cosmetic';
    case PassRewardKind.boost:
      return '2× boost · ${reward.hours}h';
  }
}
