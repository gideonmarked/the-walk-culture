/// Character health ladder — the forced replacement for the old user-set daily
/// goal. The player can't pick a target any more: every day is graded against
/// fixed thresholds, and the character climbs or slides accordingly.
library;

/// Walk at least this and you keep the level you have.
const int kHoldSteps = 5000;

/// Walk at least this and you climb one level.
const int kClimbSteps = 10000;

class HealthLevel {
  final String name;
  final String emoji;
  const HealthLevel(this.name, this.emoji);
}

/// Worst → best. Index into this list IS the level.
const List<HealthLevel> kHealthLevels = [
  // The name is a walking-pace theme; the art shows the matching POSTURE, from
  // laying flat (Idle) up to striding tall (Soaring, animated later).
  HealthLevel('Idle', '🛌'), // laying down
  HealthLevel('Sluggish', '🐌'), // crawling
  HealthLevel('Strolling', '🚶'), // hunched, trudging
  HealthLevel('Steady', '🙂'), // upright, walking
  HealthLevel('Brisk', '🏃'), // brisk walk
  HealthLevel('Swift', '💨'), // striding
  HealthLevel('Soaring', '🦅'), // upright & moving (animated later)
];

/// New players start in the middle, with room to fall as well as climb.
const int kStartHealthLevel = 3; // Steady

int get _maxLevel => kHealthLevels.length - 1;

/// Clamp any level (including one loaded from an older save) into range.
int clampHealthLevel(int level) =>
    level < 0 ? 0 : (level > _maxLevel ? _maxLevel : level);

/// Grade a completed day: under [kHoldSteps] slides one level, [kHoldSteps] to
/// [kClimbSteps] holds, [kClimbSteps]+ climbs one. Pure, so it's easy to test.
int applyDailyHealth(int level, int daySteps) {
  final current = clampHealthLevel(level);
  if (daySteps >= kClimbSteps) return clampHealthLevel(current + 1);
  if (daySteps >= kHoldSteps) return current;
  return clampHealthLevel(current - 1);
}

HealthLevel healthLevelInfo(int level) => kHealthLevels[clampHealthLevel(level)];

bool isTopHealth(int level) => clampHealthLevel(level) == _maxLevel;
bool isBottomHealth(int level) => clampHealthLevel(level) == 0;
