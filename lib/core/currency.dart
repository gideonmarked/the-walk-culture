/// Currency ladder & conversion — StepQuest design doc §5.
///
/// Prototype uses the strict uniform 1000x ladder. Per the doc, swap this for
/// the recommended "B + C hybrid" (soften above Gold + a prestige track) later.
library;

const List<String> kTierNames = [
  'Steps',
  'Copper',
  'Silver',
  'Gold',
  'Titanium',
  'Platinum',
  'Tanzanite',
  'Emerald',
  'Ruby',
  'Diamond',
];

/// Each tier is 100x the previous. Softened from 1000x so that every rarity can
/// sit in its own tier and still be reachable: at 1000x a Legendary priced in
/// Titanium would cost a trillion steps (millennia of walking). At 100x:
/// Copper=100, Silver=10k, Gold=1M, Titanium=100M.
const int kTierMultiplier = 100;

/// Raw steps represented by ONE unit of [tierName]
/// (Steps=1, Copper=1_000, Silver=1_000_000, …).
int stepsPerUnit(String tierName) {
  final index = kTierNames.indexOf(tierName);
  if (index <= 0) return 1;
  var value = 1;
  for (var i = 0; i < index; i++) {
    value *= kTierMultiplier;
  }
  return value;
}

/// Raw-step cost of [amount] units of [tierName].
int priceInSteps(String tierName, int amount) =>
    stepsPerUnit(tierName) * amount;

/// Index into [kTierNames] of the highest tier [lifetimeSteps] has reached.
/// Iterates ascending and stops early, so it never computes the huge
/// (overflow-prone) high-tier thresholds for realistic step counts.
int highestTierIndex(int lifetimeSteps) {
  var idx = 0;
  for (var i = 1; i < kTierNames.length; i++) {
    if (lifetimeSteps >= stepsPerUnit(kTierNames[i])) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
}

/// Break a raw lifetime step total into per-tier balances (base-1000 positional).
/// Returns every tier name (0 for empty tiers) so displays stay stable.
Map<String, int> toWallet(int totalSteps) {
  final wallet = {for (final t in kTierNames) t: 0};
  var remaining = totalSteps < 0 ? 0 : totalSteps;
  for (final tier in kTierNames) {
    wallet[tier] = remaining % kTierMultiplier;
    remaining ~/= kTierMultiplier;
    if (remaining == 0) break;
  }
  return wallet;
}
