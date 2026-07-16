import '../models/player_state.dart';

/// How hard a trophy is to earn. Drives the easy → difficult ordering in the
/// trophy list; purely presentational.
enum Difficulty { easy, medium, hard, elite }

extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
        Difficulty.elite => 'Elite',
      };

  /// Bonus Steps paid out for a trophy of this difficulty. Additive bonus, not
  /// a re-credit of steps walked (doc §2.4 double-count rule).
  int get reward => switch (this) {
        Difficulty.easy => 500,
        Difficulty.medium => 2500,
        Difficulty.hard => 10000,
        Difficulty.elite => 50000,
      };
}

/// A milestone derived purely from [PlayerState] — no separate storage needed
/// (doc §6 achievements / trophy room).
class Achievement {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Difficulty difficulty;
  final bool Function(PlayerState) unlocked;
  const Achievement(this.id, this.name, this.emoji, this.description,
      this.difficulty, this.unlocked);

  /// Bonus Steps for earning this, scaled by how hard it is.
  int get reward => difficulty.reward;

  /// Earned, but the bonus hasn't been collected yet.
  bool claimable(PlayerState p) =>
      unlocked(p) && !p.claimedAchievements.contains(id);
}
