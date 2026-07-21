/// Daily gratitude journal — name a few things you're thankful for.
///
/// The reward is deliberately just a COMMON item: gratitude is the point, not
/// the loot. And the entries themselves are personal reflection, so they stay
/// ON THE DEVICE and are never uploaded (see GratitudeJournal — it uses its own
/// local store, not the synced player save).
library;

/// How many things to name before the day's entry counts.
const int kGratitudeCount = 3;

/// Gentle placeholders to lower the blank-page barrier.
const List<String> kGratitudeHints = [
  'Someone who helped you',
  'A small thing that went right',
  'Something you often take for granted',
];
