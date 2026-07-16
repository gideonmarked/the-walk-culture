import '../core/achievements.dart';
import '../core/health.dart';
import '../core/spheres.dart';
import 'shop_catalog.dart';

/// Every step sphere (the real-money Celestial tier doesn't count towards
/// "open them all" — it isn't earnable by walking).
final int _stepSphereCount =
    kSphereTiers.where((t) => !t.isRealMoney).length;

final int _shopItemCount = kShopCatalog.where((i) => i.inShop).length;

/// Trophies, ordered easy → difficult. Each is a pure predicate over player
/// state, so nothing extra needs storing or migrating.
final List<Achievement> kAchievements = [
  // ---- Easy: first steps, reachable in a day or two -----------------------
  Achievement('first_copper', 'First Copper', '🟤', 'Earn 1,000 lifetime steps',
      Difficulty.easy, (p) => p.lifetimeSteps >= 1000),
  Achievement('ten_k', 'Getting Started', '👟', 'Earn 10,000 lifetime steps',
      Difficulty.easy, (p) => p.lifetimeSteps >= 10000),
  Achievement('day_5k', 'Off the Couch', '🛋️', 'Walk 5,000 steps in a day',
      Difficulty.easy, (p) => p.todaySteps >= kHoldSteps),
  Achievement('first_sphere', 'Sphere Cracker', '🔓', 'Open your first sphere',
      Difficulty.easy, (p) => p.openedSpheres.isNotEmpty),
  Achievement('first_buy', 'First Purchase', '🛒', 'Own an item',
      Difficulty.easy, (p) => p.owned.isNotEmpty),
  Achievement('dressed', 'Dressed Up', '👕', 'Equip something',
      Difficulty.easy, (p) => p.equipped.isNotEmpty),
  Achievement('first_quest', 'Quester', '📜', 'Claim a daily quest',
      Difficulty.easy, (p) => p.claimedQuests.isNotEmpty),
  Achievement('streak_3', 'Three in a Row', '🔥', 'Reach a 3-day streak',
      Difficulty.easy, (p) => p.streakBest >= 3),

  // ---- Medium: a week or two of honest walking ----------------------------
  Achievement('day_10k', 'Ten Thousand Club', '🏅',
      'Walk 10,000 steps in a day', Difficulty.medium,
      (p) => p.todaySteps >= kClimbSteps),
  Achievement('fifty_k', 'Pavement Pounder', '🚶', 'Earn 50,000 lifetime steps',
      Difficulty.medium, (p) => p.lifetimeSteps >= 50000),
  Achievement('hundred_k', 'Marathoner', '🏃', 'Earn 100,000 lifetime steps',
      Difficulty.medium, (p) => p.lifetimeSteps >= 100000),
  Achievement('streak_7', 'Week Warrior', '🗓️', 'Reach a 7-day streak',
      Difficulty.medium, (p) => p.streakBest >= 7),
  Achievement('vital', 'Feeling Vital', '✨', 'Reach the Vital health level',
      Difficulty.medium, (p) => p.healthLevel >= 4),
  Achievement('shopper', 'Shopper', '🛍️', 'Own 3 items', Difficulty.medium,
      (p) => p.owned.length >= 3),
  Achievement('decorator', 'Interior Designer', '🪴',
      'Place decor in your house', Difficulty.medium,
      (p) => p.placedHome.isNotEmpty),
  Achievement('spheres_3', 'Triple Crack', '🎁',
      'Open 3 spheres in a single day', Difficulty.medium,
      (p) => p.openedSpheres.length >= 3),
  Achievement('quests_all', 'Clean Sweep', '✅',
      'Claim every daily quest in one day', Difficulty.medium,
      (p) => p.claimedQuests.length >= 3),

  // ---- Hard: sustained commitment ----------------------------------------
  Achievement('day_20k', 'Double Digits', '⚡', 'Walk 20,000 steps in a day',
      Difficulty.hard, (p) => p.todaySteps >= 20000),
  Achievement('quarter_million', 'Long Hauler', '🥾',
      'Earn 250,000 lifetime steps', Difficulty.hard,
      (p) => p.lifetimeSteps >= 250000),
  Achievement('half_million', 'Half a Million', '🧭',
      'Earn 500,000 lifetime steps', Difficulty.hard,
      (p) => p.lifetimeSteps >= 500000),
  Achievement('streak_14', 'Fortnight', '📆', 'Reach a 14-day streak',
      Difficulty.hard, (p) => p.streakBest >= 14),
  Achievement('streak_30', 'Unstoppable', '🏆', 'Reach a 30-day streak',
      Difficulty.hard, (p) => p.streakBest >= 30),
  Achievement('thriving', 'Thriving', '🌿', 'Reach the Thriving health level',
      Difficulty.hard, (p) => p.healthLevel >= 5),
  Achievement('big_spender', 'Big Spender', '💸', 'Spend 100,000 steps',
      Difficulty.hard, (p) => p.spentSteps >= 100000),
  Achievement('wardrobe', 'Wardrobe', '🧥', 'Own 10 items', Difficulty.hard,
      (p) => p.owned.length >= 10),
  Achievement('homely', 'Fully Furnished', '🏡', 'Place 3 pieces of decor',
      Difficulty.hard, (p) => p.placedHome.length >= 3),

  // ---- Elite: the long game ----------------------------------------------
  Achievement('day_30k', 'Ultra Day', '🌋', 'Walk 30,000 steps in a day',
      Difficulty.elite, (p) => p.todaySteps >= 30000),
  Achievement('silver', 'Silver Walker', '⚪', 'Earn 1,000,000 lifetime steps',
      Difficulty.elite, (p) => p.lifetimeSteps >= 1000000),
  Achievement('five_million', 'Legend of the Walk', '🌍',
      'Earn 5,000,000 lifetime steps', Difficulty.elite,
      (p) => p.lifetimeSteps >= 5000000),
  Achievement('streak_100', 'Century Streak', '💯', 'Reach a 100-day streak',
      Difficulty.elite, (p) => p.streakBest >= 100),
  Achievement('radiant', 'Radiant', '🌟',
      'Reach the top health level, Radiant', Difficulty.elite,
      (p) => isTopHealth(p.healthLevel)),
  Achievement('spheres_all', 'Sphere Master', '🔮',
      'Open every step sphere in one day', Difficulty.elite,
      (p) => p.openedSpheres.length >= _stepSphereCount),
  Achievement('collector', 'Collector', '💎', 'Own every shop item',
      Difficulty.elite, (p) => p.owned.length >= _shopItemCount),
];
