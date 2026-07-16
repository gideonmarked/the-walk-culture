/// Pure streak logic (doc §5.2) — kept side-effect-free so it's easy to test.
library;

class StreakUpdate {
  final int current;
  final int best;
  final String lastMetDate;
  const StreakUpdate(this.current, this.best, this.lastMetDate);
}

/// Compute the new streak given prior state and whether today's goal is met.
/// [today]/[yesterday] are 'y-m-d' day keys produced the same way everywhere.
StreakUpdate computeStreak({
  required int current,
  required int best,
  required String lastMetDate,
  required String today,
  required String yesterday,
  required bool goalMet,
}) {
  if (!goalMet) return StreakUpdate(current, best, lastMetDate);
  if (lastMetDate == today) {
    return StreakUpdate(current, best, lastMetDate); // already counted today
  }
  final next = (lastMetDate == yesterday) ? current + 1 : 1;
  final newBest = next > best ? next : best;
  return StreakUpdate(next, newBest, today);
}

/// Canonical day key used across the app for streak comparisons.
String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
