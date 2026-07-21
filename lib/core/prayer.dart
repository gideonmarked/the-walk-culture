/// Daily "pray for someone" — a two-minute reflective pause with its own
/// once-a-day reward. Parallel to the Bible verse (see core/bible.dart), but a
/// longer commitment, so the reward odds lean a little kinder.
library;

import '../models/shop_item.dart' show Rarity;

/// How long the prayer timer runs before the reward unlocks.
const Duration kPrayerDuration = Duration(minutes: 2);

/// Gentle prompts shown while praying (rotates so it isn't stale).
const List<String> kPrayerPrompts = [
  'Hold them in your heart. Ask for peace, healing, and strength for them today.',
  'Pray for someone who is hurting — that they would feel comforted and not alone.',
  'Lift up a friend or family member. Ask that good would come to them.',
  'Pray for someone you find hard to love, and for a softer heart yourself.',
  'Give thanks for someone, and ask a blessing over their day.',
];

String prayerPromptForToday([DateTime? now]) {
  final d = now ?? DateTime.now();
  final dayOfYear = d.difference(DateTime(d.year)).inDays;
  return kPrayerPrompts[dayOfYear % kPrayerPrompts.length];
}

/// Drop odds for the prayer reward, in percent (must sum to 100). A touch more
/// generous than the Bible read, reflecting the longer two-minute commitment.
const Map<Rarity, double> kPrayerRewardOdds = {
  Rarity.common: 60.0,
  Rarity.uncommon: 26.0,
  Rarity.rare: 10.0,
  Rarity.epic: 3.5,
  Rarity.legendary: 0.5,
};

// ---- Prayer Walk ------------------------------------------------------------
// Pray while you walk: your real steps are the timer. A prompt surfaces every
// [kPrayerWalkPromptInterval] steps until you reach [kPrayerWalkTargetSteps].
// Reuses [kPrayerRewardOdds] — the reward stays a quiet bonus, not the point.

const int kPrayerWalkTargetSteps = 1000;
const int kPrayerWalkPromptInterval = 200;

/// One prompt per interval, in order. Keep them centred on the practice.
const List<String> kPrayerWalkPrompts = [
  'Begin with thanks — for breath, for this body that can move, for today.',
  'Pray for the people you love. Hold each of them before God as you walk.',
  'Bring someone who is hurting to mind. Ask for their healing and peace.',
  'Let go of what weighs on you. Ask for a lighter, cleaner heart.',
  'Pray over your own day — that you would walk in kindness and patience.',
];
