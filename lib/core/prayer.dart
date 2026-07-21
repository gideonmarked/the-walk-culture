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
