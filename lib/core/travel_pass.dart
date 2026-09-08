/// Travel Pass — the seasonal reward track (doc §11 roadmap: "cosmetic pass").
///
/// Thirty levels, two tracks. Everyone climbs the same ladder by WALKING; VIPs
/// unlock a second column of rewards on it. Pure logic + the reward table, so
/// pacing is testable without a widget or a store in the loop.
///
/// Three rules hold this together and the tests pin all three:
///
///  1. **XP is raw walked steps.** The VIP 2× earning perk and the temporary
///     boost multiply *currency*, never pass XP — otherwise money would buy
///     progress on the ladder, and "1 real step = 1 step" stops being true.
///  2. **Every reward is named.** No random boxes anywhere on the track, paid
///     or free (design invariant §5).
///  3. **VIP gates rewards, not the climb.** A free player reaches level 30;
///     they just can't open the VIP column. Subscribe later and every VIP
///     reward you already earned is still there to claim.
library;

// ---- Seasons ----------------------------------------------------------------

/// Length of one season. 30 levels × [kPassLevelXp] = 240,000 XP, so finishing
/// takes ~4,000 steps a day across the season — under the 5,000 that holds your
/// health level, i.e. anyone keeping their ladder steady completes the pass.
const int kSeasonDays = 60;

/// Season 1 began here. Seasons are derived from this instant rather than
/// stored, so every device (and, later, the server) agrees on which season it
/// is without a round trip. UTC so a traveller crossing timezones doesn't
/// bounce between seasons.
final DateTime kSeasonEpoch = DateTime.utc(2026, 1, 5);

/// A season's flavour. Cycles once [kSeasonThemes] runs out, so the pass keeps
/// naming seasons forever without a content drop.
class SeasonTheme {
  const SeasonTheme(this.name, this.emoji);
  final String name;
  final String emoji;
}

const List<SeasonTheme> kSeasonThemes = [
  SeasonTheme('First Steps', '👣'),
  SeasonTheme('The Long Road', '🛣️'),
  SeasonTheme('Highland Trail', '⛰️'),
  SeasonTheme('Desert Crossing', '🏜️'),
  SeasonTheme('River Path', '🏞️'),
  SeasonTheme('Starlit Way', '🌌'),
];

/// One concrete season: which number it is, what it's called, and its window.
class PassSeason {
  const PassSeason({
    required this.index,
    required this.start,
    required this.end,
  });

  /// 0-based season number since [kSeasonEpoch].
  final int index;
  final DateTime start;
  final DateTime end;

  /// Stable id stored alongside pass progress; a mismatch means "new season,
  /// reset the track".
  String get id => 's$index';

  SeasonTheme get theme => kSeasonThemes[index % kSeasonThemes.length];

  /// "Season 5 — River Path"
  String get name => 'Season ${index + 1} — ${theme.name}';
  String get emoji => theme.emoji;

  /// Whole days left, rounded up, so the last partial day still reads "1 day
  /// left" instead of "0".
  int daysLeftAt(DateTime now) {
    final ms = end.difference(now.toUtc()).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / Duration.millisecondsPerDay).ceil();
  }
}

/// The season index encoded in an id like `'s4'`, or null when [id] isn't one
/// (`''` on a save from before the pass, or a format we don't know). Lets the
/// rollover check tell "the calendar moved on" apart from "this clock is wrong".
int? seasonIndexFromId(String id) {
  if (id.length < 2 || !id.startsWith('s')) return null;
  return int.tryParse(id.substring(1));
}

/// The season [now] falls in. Anything before the epoch is treated as season 0
/// (a device with a badly wrong clock gets season 1, never a negative one).
PassSeason seasonAt(DateTime now) {
  final elapsed = now.toUtc().difference(kSeasonEpoch).inMilliseconds;
  const period = kSeasonDays * Duration.millisecondsPerDay;
  final index = elapsed <= 0 ? 0 : elapsed ~/ period;
  final start = kSeasonEpoch.add(Duration(milliseconds: index * period));
  return PassSeason(
    index: index,
    start: start,
    end: start.add(const Duration(days: kSeasonDays)),
  );
}

// ---- Levels -----------------------------------------------------------------

/// Levels in a season's track.
const int kPassLevelCount = 30;

/// XP per level — flat, not a curve. A rising cost makes the last levels a
/// grind and the pass a chore; flat means "walk this much per day and you
/// finish", which is the promise we actually want to make.
const int kPassLevelXp = 8000;

/// Gentle top-ups so the rest of the loop feeds the pass and a rest day still
/// inches forward. Deliberately tiny next to [kPassLevelXp] — walking has to
/// stay the way you climb, and devotions must never become the fast lane
/// (design invariant §6).
const int kPassXpPerQuest = 100;
const int kPassXpPerDevotion = 100;
const int kPassXpPerSphere = 50;

/// Total XP to have *reached* [level] (level 1 needs [kPassLevelXp]).
int xpForLevel(int level) => level <= 0 ? 0 : level * kPassLevelXp;

/// Level reached with [xp], capped at [kPassLevelCount]. 0 = not there yet.
int passLevelForXp(int xp) {
  if (xp <= 0) return 0;
  final level = xp ~/ kPassLevelXp;
  return level > kPassLevelCount ? kPassLevelCount : level;
}

/// XP banked toward the NEXT level. Reads 0 once the track is maxed, so the
/// header doesn't dangle a bar that can never fill.
int passXpIntoLevel(int xp) {
  if (passLevelForXp(xp) >= kPassLevelCount) return 0;
  return xp <= 0 ? 0 : xp % kPassLevelXp;
}

/// Progress to the next level, 0..1. Full when the track is maxed.
double passLevelProgress(int xp) {
  if (passLevelForXp(xp) >= kPassLevelCount) return 1;
  return passXpIntoLevel(xp) / kPassLevelXp;
}

// ---- Rewards ----------------------------------------------------------------

enum PassRewardKind {
  /// Spendable bonus currency, credited like any other grant.
  pebbles,

  /// A specific cosmetic, by id. Always a pass-exclusive one (see
  /// `lib/data/pass_catalog.dart`) so a reward can't be something you already
  /// bought in the shop.
  item,

  /// Hours of the 2× earning boost.
  boost,
}

/// One cell on the track. Named and guaranteed — never a roll.
class PassReward {
  const PassReward._(this.kind,
      {this.amount = 0, this.itemId = '', this.hours = 0});

  const PassReward.pebbles(int amount)
      : this._(PassRewardKind.pebbles, amount: amount);
  const PassReward.item(String itemId)
      : this._(PassRewardKind.item, itemId: itemId);
  const PassReward.boost(int hours)
      : this._(PassRewardKind.boost, hours: hours);

  final PassRewardKind kind;
  final int amount; // pebbles
  final String itemId; // item
  final int hours; // boost
}

/// One rung: the free cell (may be empty) and the VIP cell (never empty — the
/// VIP column is what's being paid for, so it always carries something).
class PassLevel {
  const PassLevel(this.level, {this.free, required this.vip});

  final int level;
  final PassReward? free;
  final PassReward vip;
}

/// The season track. Free side: steady Pebbles with five cosmetics at the
/// milestones. VIP side: the twelve pass-exclusive cosmetics, the boosts, and
/// the fat Pebble bags — the "some items you only get as a VIP" the whole
/// feature exists for.
const List<PassLevel> kPassTrack = [
  PassLevel(1, free: PassReward.pebbles(1000), vip: PassReward.pebbles(3000)),
  PassLevel(2, free: PassReward.pebbles(1000), vip: PassReward.boost(2)),
  PassLevel(3, free: PassReward.pebbles(1500), vip: PassReward.item('pass_vip_sash')),
  PassLevel(4, vip: PassReward.pebbles(4000)),
  PassLevel(5, free: PassReward.item('pass_trail_cap'), vip: PassReward.pebbles(4000)),
  PassLevel(6, free: PassReward.pebbles(1500), vip: PassReward.item('pass_vip_cloak')),
  PassLevel(7, free: PassReward.pebbles(2000), vip: PassReward.pebbles(5000)),
  PassLevel(8, vip: PassReward.boost(3)),
  PassLevel(9, free: PassReward.pebbles(2000), vip: PassReward.item('pass_vip_compass')),
  PassLevel(10, free: PassReward.pebbles(5000), vip: PassReward.pebbles(10000)),
  PassLevel(11, free: PassReward.pebbles(2000), vip: PassReward.pebbles(5000)),
  PassLevel(12, free: PassReward.item('pass_wayfarer_tee'), vip: PassReward.pebbles(6000)),
  PassLevel(13, free: PassReward.pebbles(2500), vip: PassReward.item('pass_vip_hat')),
  PassLevel(14, vip: PassReward.boost(3)),
  PassLevel(15, free: PassReward.pebbles(3000), vip: PassReward.pebbles(8000)),
  PassLevel(16, free: PassReward.pebbles(2500), vip: PassReward.item('pass_vip_camel')),
  PassLevel(17, vip: PassReward.pebbles(8000)),
  PassLevel(18, free: PassReward.pebbles(3000), vip: PassReward.pebbles(8000)),
  PassLevel(19, free: PassReward.pebbles(3000), vip: PassReward.item('pass_vip_braid')),
  PassLevel(20, free: PassReward.item('pass_dust_boots'), vip: PassReward.pebbles(15000)),
  PassLevel(21, free: PassReward.pebbles(3500), vip: PassReward.boost(4)),
  PassLevel(22, vip: PassReward.item('pass_vip_coat')),
  PassLevel(23, free: PassReward.pebbles(3500), vip: PassReward.pebbles(10000)),
  PassLevel(24, free: PassReward.pebbles(4000), vip: PassReward.item('pass_vip_boots')),
  PassLevel(25, free: PassReward.item('pass_lantern'), vip: PassReward.pebbles(12000)),
  PassLevel(26, free: PassReward.pebbles(4000), vip: PassReward.item('pass_vip_phoenix')),
  PassLevel(27, vip: PassReward.boost(6)),
  PassLevel(28, free: PassReward.pebbles(5000), vip: PassReward.item('pass_vip_mantle')),
  PassLevel(29, free: PassReward.pebbles(5000), vip: PassReward.item('pass_vip_crown')),
  PassLevel(30, free: PassReward.item('pass_pilgrim_staff'), vip: PassReward.item('pass_vip_halo')),
];

/// The track entry for [level] (1-based), or null if [level] is off the track.
PassLevel? passLevelAt(int level) =>
    (level < 1 || level > kPassLevelCount) ? null : kPassTrack[level - 1];

/// How many cosmetics the VIP column holds — the headline number on the upsell.
int get vipExclusiveItemCount =>
    kPassTrack.where((l) => l.vip.kind == PassRewardKind.item).length;
