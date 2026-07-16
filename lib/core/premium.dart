/// Monetization catalogue — the paid SKUs and the rewarded-ad economy.
///
/// IMPORTANT: the `priceLabel`s here are display fallbacks only. Real prices,
/// currencies, and the actual charge come from the store (Google Play Billing /
/// Apple StoreKit) at runtime via the `in_app_purchase` plugin — never trust a
/// price baked into the app. The [storeProductId]s are what you register in the
/// Play/App Store consoles; validate every purchase server-side (Supabase Edge
/// Function) before granting the entitlement.
library;

/// A one-time / consumable currency pack bought with real money. The steps are
/// credited to the wallet as spendable currency (never to the health ladder —
/// money must not buy health outcomes).
class CurrencyPack {
  const CurrencyPack({
    required this.id,
    required this.storeProductId,
    required this.label,
    required this.steps,
    required this.priceLabel,
    this.bestValue = false,
  });

  final String id;
  final String storeProductId; // register this in Play/App Store console
  final String label;
  final int steps; // spendable currency granted
  final String priceLabel; // display fallback only
  final bool bestValue;
}

const List<CurrencyPack> kCurrencyPacks = [
  CurrencyPack(
    id: 'pack_pouch',
    storeProductId: 'com.perfeos.step_quest.currency.pouch',
    label: 'Step Pouch',
    steps: 10000,
    priceLabel: '\$0.99',
  ),
  CurrencyPack(
    id: 'pack_sack',
    storeProductId: 'com.perfeos.step_quest.currency.sack',
    label: 'Step Sack',
    steps: 60000,
    priceLabel: '\$4.99',
  ),
  CurrencyPack(
    id: 'pack_chest',
    storeProductId: 'com.perfeos.step_quest.currency.chest',
    label: 'Step Chest',
    steps: 150000,
    priceLabel: '\$9.99',
    bestValue: true,
  ),
  CurrencyPack(
    id: 'pack_vault',
    storeProductId: 'com.perfeos.step_quest.currency.vault',
    label: 'Step Vault',
    steps: 400000,
    priceLabel: '\$19.99',
  ),
];

/// A VIP subscription plan — an auto-renewing store subscription, NOT a
/// hand-rolled timer. The store owns renewal/grace/refunds; the app only reads
/// the entitlement (an expiry timestamp) after server-side validation.
class VipPlan {
  const VipPlan({
    required this.id,
    required this.storeProductId,
    required this.label,
    required this.days,
    required this.priceLabel,
    this.highlight = false,
  });

  final String id;
  final String storeProductId;
  final String label;
  final int days; // entitlement length granted per period
  final String priceLabel;
  final bool highlight;
}

const List<VipPlan> kVipPlans = [
  VipPlan(
    id: 'vip_weekly',
    storeProductId: 'com.perfeos.step_quest.vip.weekly',
    label: 'Weekly VIP',
    days: 7,
    priceLabel: '\$1.99 / wk',
  ),
  VipPlan(
    id: 'vip_monthly',
    storeProductId: 'com.perfeos.step_quest.vip.monthly',
    label: 'Monthly VIP',
    days: 30,
    priceLabel: '\$4.99 / mo',
    highlight: true,
  ),
  VipPlan(
    id: 'vip_annual',
    storeProductId: 'com.perfeos.step_quest.vip.annual',
    label: 'Annual VIP',
    days: 365,
    priceLabel: '\$29.99 / yr',
  ),
];

/// Human-readable VIP perks — kept here so the store and any marketing copy
/// stay in sync. Deliberately convenience + cosmetic + soft-economy: money must
/// never buy a health outcome (that would corrupt the whole premise).
const List<String> kVipPerks = [
  '2× step-currency earning, always on',
  'Daily VIP currency stipend',
  'An extra free rewarded ad each day',
  'Exclusive VIP badge on your profile',
];

/// Steps auto-credited each day the player is VIP.
const int kVipDailyStipend = 5000;

// ---- Rewarded ads -----------------------------------------------------------

/// Spendable steps granted for watching one rewarded ad.
const int kAdRewardSteps = 2000;

/// Base daily cap on rewarded ads; VIPs get [kVipExtraAdsPerDay] more.
const int kAdRewardsPerDay = 5;
const int kVipExtraAdsPerDay = 1;
