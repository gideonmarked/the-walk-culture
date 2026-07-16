import '../models/player_state.dart';
import 'health.dart';

/// A daily quest: reach a step target today for a bonus-currency reward
/// (doc §6 quests/challenges). Rewards are additive bonus Steps, never a
/// re-credit of walked steps (doc §2.4 double-count rule).
class Quest {
  final String id;
  final String title;

  /// Step target for today. Fixed — there is no player-set goal any more; the
  /// targets line up with the health ladder's hold/climb thresholds.
  final int targetSteps;

  /// Bonus Steps granted on claim.
  final int reward;

  const Quest(this.id, this.title, this.targetSteps, this.reward);

  int effectiveTarget(PlayerState p) => targetSteps;

  bool isCompleted(PlayerState p) => p.todaySteps >= effectiveTarget(p);
}

const List<Quest> kDailyQuests = [
  Quest('q_3k', 'Walk 3,000 steps today', 3000, 200),
  Quest('q_goal', 'Hold your health — 5,000 steps', kHoldSteps, 500),
  Quest('q_10k', 'Climb a health level — 10,000 steps', kClimbSteps, 1000),
];
