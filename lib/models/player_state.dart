import '../core/health.dart';
import 'shop_item.dart';

/// Immutable player snapshot. Per doc §8, the wallet is DERIVED from two
/// numbers — lifetimeSteps and spentSteps — never stored per-tier.
class PlayerState {
  final int lifetimeSteps;
  final int spentSteps;
  final int todaySteps; // today's cumulative count (display + delta math)

  // Character health ladder (index into kHealthLevels) — graded once per day
  // from that day's steps. Not player-configurable; replaces the old dailyGoal.
  final int healthLevel;

  // Streaks (doc §5.2 / §6). A day counts once it clears kHoldSteps.
  final int streakCurrent;
  final int streakBest;
  final String lastGoalMetDate; // 'y-m-d' day key, '' if never

  // Daily quests (doc §6). Reset each day.
  final String questDay; // 'y-m-d' the claimedQuests set belongs to
  final Set<String> claimedQuests;

  // Trophies whose step bonus has been collected. Permanent — unlike quests,
  // this NEVER resets, or trophies would pay out again every day.
  final Set<String> claimedAchievements;

  // Highest currency tier index ever reached (drives the tier-up celebration).
  final int highestTierReached;

  // 2x earning boost active until this epoch-millis (0 = no boost). Doc §5.2.
  final int boostUntilMs;

  // Mystery Sphere tiers already opened today (doc §6). Reset daily. A tier
  // unlocks when todaySteps reaches its threshold and can be opened once/day.
  final Set<String> openedSpheres;

  // What each sphere opened today actually paid out, so the day's opens can be
  // listed back as a summary. Keyed by tier id; values are encoded rewards
  // ('item:<id>' or 'steps:<n>' — see encodeSphereReward). Reset daily.
  final Map<String, String> sphereRewards;

  // Inventory.
  final Set<String> owned;
  final Map<ItemSlot, String> equipped; // wearable slots (single per slot)
  final Set<String> placedHome; // home-decor items placed in the room

  // Social identity. `accountCode` is the shareable 7-char code (e.g. A7A43B7)
  // others use to friend you; generated once, then stable. `username` is chosen
  // by the player. Both become server-authoritative (unique) once the backend
  // is live — until then this local copy is what the Profile shows.
  final String username;
  final String accountCode;

  const PlayerState({
    this.lifetimeSteps = 0,
    this.spentSteps = 0,
    this.todaySteps = 0,
    this.healthLevel = kStartHealthLevel,
    this.streakCurrent = 0,
    this.streakBest = 0,
    this.lastGoalMetDate = '',
    this.questDay = '',
    this.claimedQuests = const {},
    this.claimedAchievements = const {},
    this.highestTierReached = 0,
    this.boostUntilMs = 0,
    this.openedSpheres = const {},
    this.sphereRewards = const {},
    this.owned = const {},
    this.equipped = const {},
    this.placedHome = const {},
    this.username = '',
    this.accountCode = '',
  });

  int get spendableSteps => lifetimeSteps - spentSteps;

  PlayerState copyWith({
    int? lifetimeSteps,
    int? spentSteps,
    int? todaySteps,
    int? healthLevel,
    int? streakCurrent,
    int? streakBest,
    String? lastGoalMetDate,
    String? questDay,
    Set<String>? claimedQuests,
    Set<String>? claimedAchievements,
    int? highestTierReached,
    int? boostUntilMs,
    Set<String>? openedSpheres,
    Map<String, String>? sphereRewards,
    Set<String>? owned,
    Map<ItemSlot, String>? equipped,
    Set<String>? placedHome,
    String? username,
    String? accountCode,
  }) {
    return PlayerState(
      lifetimeSteps: lifetimeSteps ?? this.lifetimeSteps,
      spentSteps: spentSteps ?? this.spentSteps,
      todaySteps: todaySteps ?? this.todaySteps,
      healthLevel: healthLevel ?? this.healthLevel,
      streakCurrent: streakCurrent ?? this.streakCurrent,
      streakBest: streakBest ?? this.streakBest,
      lastGoalMetDate: lastGoalMetDate ?? this.lastGoalMetDate,
      questDay: questDay ?? this.questDay,
      claimedQuests: claimedQuests ?? this.claimedQuests,
      claimedAchievements: claimedAchievements ?? this.claimedAchievements,
      highestTierReached: highestTierReached ?? this.highestTierReached,
      boostUntilMs: boostUntilMs ?? this.boostUntilMs,
      openedSpheres: openedSpheres ?? this.openedSpheres,
      sphereRewards: sphereRewards ?? this.sphereRewards,
      owned: owned ?? this.owned,
      equipped: equipped ?? this.equipped,
      placedHome: placedHome ?? this.placedHome,
      username: username ?? this.username,
      accountCode: accountCode ?? this.accountCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'lifetimeSteps': lifetimeSteps,
        'spentSteps': spentSteps,
        'todaySteps': todaySteps,
        'healthLevel': healthLevel,
        'streakCurrent': streakCurrent,
        'streakBest': streakBest,
        'lastGoalMetDate': lastGoalMetDate,
        'questDay': questDay,
        'claimedQuests': claimedQuests.toList(),
        'claimedAchievements': claimedAchievements.toList(),
        'highestTierReached': highestTierReached,
        'boostUntilMs': boostUntilMs,
        'openedSpheres': openedSpheres.toList(),
        'sphereRewards': sphereRewards,
        'owned': owned.toList(),
        'equipped': {for (final e in equipped.entries) e.key.name: e.value},
        'placedHome': placedHome.toList(),
        'username': username,
        'accountCode': accountCode,
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    final equipped = <ItemSlot, String>{};
    final rawEquipped = (json['equipped'] as Map?) ?? const {};
    rawEquipped.forEach((key, value) {
      final match = ItemSlot.values.where((s) => s.name == key);
      if (match.isNotEmpty && value is String) equipped[match.first] = value;
    });
    Set<String> strSet(dynamic v) =>
        ((v as List?) ?? const []).map((e) => e as String).toSet();
    return PlayerState(
      lifetimeSteps: (json['lifetimeSteps'] as num?)?.toInt() ?? 0,
      spentSteps: (json['spentSteps'] as num?)?.toInt() ?? 0,
      todaySteps: (json['todaySteps'] as num?)?.toInt() ?? 0,
      // Saves written before the health ladder existed have no level — those
      // players start at Balanced rather than inheriting a bogus 0 (Withered).
      healthLevel: clampHealthLevel(
          (json['healthLevel'] as num?)?.toInt() ?? kStartHealthLevel),
      streakCurrent: (json['streakCurrent'] as num?)?.toInt() ?? 0,
      streakBest: (json['streakBest'] as num?)?.toInt() ?? 0,
      lastGoalMetDate: (json['lastGoalMetDate'] as String?) ?? '',
      questDay: (json['questDay'] as String?) ?? '',
      claimedQuests: strSet(json['claimedQuests']),
      claimedAchievements: strSet(json['claimedAchievements']),
      highestTierReached: (json['highestTierReached'] as num?)?.toInt() ?? 0,
      boostUntilMs: (json['boostUntilMs'] as num?)?.toInt() ?? 0,
      openedSpheres: strSet(json['openedSpheres']),
      sphereRewards: {
        for (final e in ((json['sphereRewards'] as Map?) ?? const {}).entries)
          if (e.value is String) e.key as String: e.value as String,
      },
      owned: strSet(json['owned']),
      equipped: equipped,
      placedHome: strSet(json['placedHome']),
      username: (json['username'] as String?) ?? '',
      accountCode: (json['accountCode'] as String?) ?? '',
    );
  }
}
