import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/achievements.dart';
import '../core/currency.dart';
import '../core/health.dart';
import '../core/premium.dart';
import '../core/quests.dart';
import '../core/spheres.dart';
import '../core/streaks.dart';
import '../data/shop_catalog.dart';
import '../models/player_state.dart';
import '../models/shop_item.dart';
import '../services/cloud/cloud_sync_service.dart';
import '../services/health_service.dart';
import 'premium_providers.dart';

/// Set false in tests to keep timers, health polling, and the pedometer inert.
bool kEnableBackgroundServices = true;

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

/// Set to a tier name (e.g. "Copper") the moment the player first reaches it,
/// so the UI can show a celebration; the UI resets it to null after showing.
final tierUpProvider = StateProvider<String?>((ref) => null);

final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>(
  (ref) => PlayerController(ref, ref.read(healthServiceProvider)),
);

/// Live, per-step "today" counter for the ticking-up feel (doc §2.1). Uses the
/// device pedometer for real-time increments and re-baselines to the
/// authoritative health total on every sync. Null until the sensor emits.
final liveStepsProvider =
    StateNotifierProvider<LiveStepsController, int?>((ref) => LiveStepsController(ref));

class LiveStepsController extends StateNotifier<int?> {
  LiveStepsController(this._ref) : super(null) {
    _start();
  }

  final Ref _ref;
  StreamSubscription<StepCount>? _sub;
  int? _lastCumulative; // latest raw pedometer reading (steps since boot)
  int? _baseline; // pedometer reading at the last re-baseline
  int _baseToday = 0; // authoritative "today" at the last re-baseline

  void _start() {
    _baseToday = _ref.read(playerControllerProvider).todaySteps;
    state = _baseToday;

    // Re-snap to the authoritative health total whenever a sync updates it.
    _ref.listen<int>(
      playerControllerProvider.select((p) => p.todaySteps),
      (previous, next) {
        _baseToday = next;
        _baseline = _lastCumulative;
        state = next;
      },
    );

    // Start the sensor only after onboarding (avoids a cold permission prompt).
    if (_ref.read(onboardingProvider)) _subscribe();
    _ref.listen<bool>(onboardingProvider, (previous, next) {
      if (next) _subscribe();
    });
  }

  Future<void> _subscribe() async {
    if (!kEnableBackgroundServices || _sub != null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.activityRecognition.request();
      }
      _sub = Pedometer.stepCountStream
          .listen(_onStep, onError: (_) {}, cancelOnError: false);
    } catch (_) {/* sensor unavailable — live ticker just stays off */}
  }

  void _onStep(StepCount event) {
    _lastCumulative = event.steps;
    _baseline ??= event.steps;
    state = _baseToday + (event.steps - _baseline!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Tracks whether the user has finished the onboarding/consent flow (doc §3.6).
final onboardingProvider =
    StateNotifierProvider<OnboardingController, bool>((ref) => OnboardingController());

class OnboardingController extends StateNotifier<bool> {
  OnboardingController() : super(false) {
    _load();
  }
  static const _key = 'stepquest_onboarded_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

/// Whether the health store is allowed to drive today's count. Turning this off
/// stops every sync (auto-poll and manual), which is what keeps simulated steps
/// from being reverted: a sync overwrites `todaySteps` with the health total,
/// so any steps added by hand would otherwise vanish on the next poll.
final healthSyncProvider = StateNotifierProvider<HealthSyncController, bool>(
    (ref) => HealthSyncController());

class HealthSyncController extends StateNotifier<bool> {
  HealthSyncController() : super(true) {
    _load();
  }

  /// Public so PlayerController can read the saved flag straight from prefs on
  /// startup — this controller's own load is async and may not have landed yet.
  static const prefsKey = 'stepquest_health_sync_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(prefsKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
  }
}

/// Owns the wallet + inventory, the passive step-sync loop (doc §2.3/§2.4), and
/// the daily-goal streak.
class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(this._ref, this._health) : super(const PlayerState()) {
    _init();
  }

  final Ref _ref;
  final HealthService _health;
  static const _stateKey = 'stepquest_player_v1';
  static const _dateKey = 'stepquest_lastsync_date_v1';
  String _lastSyncDate = '';
  Timer? _autoSync;
  bool _syncing = false;

  /// Poll the health store on an interval while the app is open, so steps tick
  /// up on their own (doc §2.3: sync on foreground). Display-only feel; the
  /// health store remains the authoritative source.
  void startAutoSync({Duration interval = const Duration(seconds: 5)}) {
    if (!kEnableBackgroundServices) return;
    _autoSync?.cancel();
    _autoSync = Timer.periodic(interval, (_) => syncSteps());
  }

  void stopAutoSync() {
    _autoSync?.cancel();
    _autoSync = null;
  }

  @override
  void dispose() {
    _autoSync?.cancel();
    _cloudDebounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw != null) {
      try {
        state = PlayerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Failed to load saved player state: $e');
      }
    }
    // Fresh install with a cloud backup → pull the player's progress back.
    await _restoreFromCloudIfEmpty(raw != null);
    _lastSyncDate = prefs.getString(_dateKey) ?? '';
    // Baseline the tier marker silently so we don't fire a celebration for
    // progress made before this feature existed.
    state = state.copyWith(
        highestTierReached: highestTierIndex(state.lifetimeSteps));
    // doc §2.3: sync on app open — but only if the user hasn't paused sync.
    // Read prefs directly: healthSyncProvider's own load may not have run yet.
    if (prefs.getBool(HealthSyncController.prefsKey) ?? true) {
      await syncSteps();
    }
    startAutoSync(); // then keep it fresh every few seconds while open
    await _maybeGrantVipStipend(); // credit the day's VIP stipend, if owed
  }

  /// Pay out the once-daily VIP stipend when it's due. Best-effort on launch —
  /// premium state loads async, so a stipend earned right after a mid-session
  /// upgrade is instead credited by the store flow calling this.
  Future<void> maybeGrantVipStipend() => _maybeGrantVipStipend();

  Future<void> _maybeGrantVipStipend() async {
    final premium = _ref.read(premiumControllerProvider.notifier);
    if (!premium.stipendDueToday) return;
    await premium.markStipendPaid();
    await grantBonusSteps(kVipDailyStipend);
  }

  /// Credit spendable currency that did NOT come from walking — IAP packs, ad
  /// rewards, the VIP stipend. Routed through lifetimeSteps like every other
  /// bonus, so it's spendable, but it never touches todaySteps or the health
  /// ladder: money and ads buy cosmetics, never health outcomes.
  Future<void> grantBonusSteps(int steps) async {
    if (steps <= 0) return;
    state = state.copyWith(lifetimeSteps: state.lifetimeSteps + steps);
    _checkTierUp();
    await _save();
  }

  /// Fire a one-shot tier-up event when lifetime steps cross into a new tier.
  void _checkTierUp() {
    final idx = highestTierIndex(state.lifetimeSteps);
    if (idx > state.highestTierReached) {
      state = state.copyWith(highestTierReached: idx);
      _ref.read(tierUpProvider.notifier).state = kTierNames[idx];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(state.toJson()));
    await prefs.setString(_dateKey, _lastSyncDate);
    _scheduleCloudBackup();
  }

  Timer? _cloudDebounce;

  /// Back the save up to the cloud, debounced. Saves fire on every step credit
  /// (up to every 5s), so pushing each one would hammer the backend for nothing.
  /// Fire-and-forget: a failed backup must never interrupt play.
  void _scheduleCloudBackup() {
    final cloud = _ref.read(cloudSyncProvider);
    if (!cloud.isReady) return;
    _cloudDebounce?.cancel();
    _cloudDebounce = Timer(const Duration(seconds: 10), () {
      cloud.pushSave(state.toJson());
    });
  }

  /// Adopt the cloud save when this device has nothing local — the reinstall /
  /// new-device path. When both exist we keep local: it's the live session, and
  /// the blob is only a backup. A real merge needs server-authoritative credits
  /// (credit_steps) rather than last-writer-wins on a blob.
  Future<void> _restoreFromCloudIfEmpty(bool hadLocalSave) async {
    if (hadLocalSave) return;
    final cloud = _ref.read(cloudSyncProvider);
    if (!cloud.isReady) return;
    final remote = await cloud.pullSave();
    if (remote == null) return;
    try {
      state = PlayerState.fromJson(remote);
      debugPrint('Restored player state from cloud backup');
    } catch (e) {
      debugPrint('Cloud save was unreadable, keeping fresh state: $e');
    }
  }

  String get _todayKey => dayKey(DateTime.now());

  /// Whether a 2x earning boost is currently active (doc §5.2).
  bool get boostActive =>
      state.boostUntilMs > DateTime.now().millisecondsSinceEpoch;

  /// VIP grants an always-on 2× that stacks with the temporary boost, so a VIP
  /// who also pops a boost earns 4× — keeping the boost worth using.
  int get _earnMultiplier =>
      (boostActive ? 2 : 1) *
      (_ref.read(premiumControllerProvider).isVip ? 2 : 1);

  /// Activate a 2x earning boost for [duration].
  Future<void> activateBoost({Duration duration = const Duration(hours: 1)}) async {
    final until = DateTime.now().add(duration).millisecondsSinceEpoch;
    state = state.copyWith(boostUntilMs: until);
    await _save();
  }

  /// Close out the previous day: grade the character's health against the steps
  /// walked, then reset the daily quest claims and Mystery Sphere opens.
  ///
  /// MUST run before today's step count is overwritten — at this point
  /// `state.todaySteps` still holds the finished day's total, and that number is
  /// the only record of it.
  void _rollDayIfNeeded() {
    if (state.questDay == _todayKey) return;

    // On a brand-new save there is no previous day to grade — skip the grading
    // (a 0-step "yesterday" would otherwise demote them on first launch) and
    // just stamp the day.
    final firstEverDay = state.questDay.isEmpty;
    final gradedLevel = firstEverDay
        ? state.healthLevel
        : applyDailyHealth(state.healthLevel, state.todaySteps);

    state = state.copyWith(
      healthLevel: gradedLevel,
      questDay: _todayKey,
      // A fresh day starts from zero; a sync (if enabled) immediately replaces
      // this with the health store's real total for today.
      todaySteps: 0,
      claimedQuests: <String>{},
      openedSpheres: <String>{},
      sphereRewards: <String, String>{},
    );
  }

  /// Passive credit (Layer 1): read today's total from the health store and
  /// credit only the delta since the last sync. No-op when unavailable.
  Future<void> syncSteps() async {
    // Don't prompt for health before the user has been through onboarding
    // (doc §3.6), and never let overlapping polls stack up. Skip entirely while
    // health sync is off, so hand-added steps aren't clobbered by the poll.
    if (!kEnableBackgroundServices ||
        _syncing ||
        !_ref.read(onboardingProvider) ||
        !_ref.read(healthSyncProvider)) {
      return;
    }
    _syncing = true;
    try {
      await _doSync();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _doSync() async {
    final todayTotal = await _health.getTodaySteps();
    if (todayTotal == null) return; // prototype uses addSimulatedSteps instead

    final newDay = _lastSyncDate != _todayKey;
    final alreadyCredited = newDay ? 0 : state.todaySteps;
    if (newDay) _lastSyncDate = _todayKey;

    final delta = todayTotal - alreadyCredited;
    final gained = (delta > 0 ? delta : 0) * _earnMultiplier;

    // Nothing new this poll — skip the state update so we don't rebuild the UI
    // or write to disk every 5 seconds for no reason.
    if (!newDay && gained == 0 && todayTotal == state.todaySteps) return;

    // Grade the finished day BEFORE todaySteps is replaced with the new total.
    _rollDayIfNeeded();

    state = state.copyWith(
      lifetimeSteps: state.lifetimeSteps + gained,
      todaySteps: todayTotal,
    );
    _updateStreak();
    _checkTierUp();
    await _save();
  }

  /// Prototype-only: simulate walking when no device sensor is available.
  Future<void> addSimulatedSteps(int n) async {
    // Roll first, so steps added across a midnight boundary land on the new day
    // instead of inflating the day being graded.
    _rollDayIfNeeded();
    state = state.copyWith(
      lifetimeSteps: state.lifetimeSteps + n * _earnMultiplier,
      todaySteps: state.todaySteps + n,
    );
    _updateStreak();
    _checkTierUp();
    await _save();
  }

  /// Claim a completed daily quest for its bonus Steps (once per day).
  Future<bool> claimQuest(Quest quest) async {
    _rollDayIfNeeded();
    if (state.claimedQuests.contains(quest.id)) return false;
    if (!quest.isCompleted(state)) return false;
    state = state.copyWith(
      lifetimeSteps: state.lifetimeSteps + quest.reward,
      claimedQuests: {...state.claimedQuests, quest.id},
    );
    _checkTierUp();
    await _save();
    return true;
  }

  /// Collect a trophy's bonus Steps. Once only — [PlayerState.claimedAchievements]
  /// is permanent, so a trophy can't be farmed by re-earning it.
  Future<bool> claimAchievement(Achievement achievement) async {
    if (!achievement.claimable(state)) return false;
    state = state.copyWith(
      lifetimeSteps: state.lifetimeSteps + achievement.reward,
      claimedAchievements: {...state.claimedAchievements, achievement.id},
    );
    _checkTierUp();
    await _save();
    return true;
  }

  void _updateStreak() {
    final today = _todayKey;
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final update = computeStreak(
      current: state.streakCurrent,
      best: state.streakBest,
      lastMetDate: state.lastGoalMetDate,
      today: today,
      yesterday: yesterday,
      // A day "counts" once it clears the level-holding threshold.
      goalMet: state.todaySteps >= kHoldSteps,
    );
    state = state.copyWith(
      streakCurrent: update.current,
      streakBest: update.best,
      lastGoalMetDate: update.lastMetDate,
    );
  }

  /// Returns true if the purchase succeeded. A rarity can only be bought once
  /// its wallet tier has been reached — the UI hides the Buy button in that
  /// case, but the rule is enforced here too so it can't be bypassed.
  Future<bool> buy(ShopItem item) async {
    if (state.owned.contains(item.id)) return false;
    if (!item.purchasable(state.spendableSteps)) return false;
    state = state.copyWith(
      spentSteps: state.spentSteps + item.costInSteps,
      owned: {...state.owned, item.id},
    );
    await _save();
    return true;
  }

  final Random _rng = Random();

  /// Whether [tier] is unlocked (today's steps reached its threshold) and not
  /// yet opened today — i.e. it should glow.
  bool sphereReady(SphereTier tier) =>
      !tier.isRealMoney &&
      state.todaySteps >= tier.stepCost &&
      !state.openedSpheres.contains(tier.id);

  /// Open a daily Mystery Sphere (doc §6). Requires today's steps to have
  /// reached the tier's threshold; each tier opens once per day (resets daily).
  /// Rolls rarity per the odds, grants a random unowned item of that rarity
  /// (or a currency bonus if the player already owns everything at that rarity).
  Future<SphereResult?> openSphere(SphereTier tier) async {
    _rollDayIfNeeded();
    if (!sphereReady(tier)) return null;

    final rarity = rollSphereRarity(tier, _rng.nextDouble());
    final candidates = kShopCatalog
        .where((i) => i.rarity == rarity && !state.owned.contains(i.id))
        .toList();

    var next = state.copyWith(openedSpheres: {...state.openedSpheres, tier.id});
    SphereResult result;
    if (candidates.isNotEmpty) {
      final item = candidates[_rng.nextInt(candidates.length)];
      next = next.copyWith(owned: {...next.owned, item.id});
      result = SphereResult(rarity: rarity, item: item);
    } else {
      final bonus = fallbackBonusFor(rarity);
      next = next.copyWith(lifetimeSteps: next.lifetimeSteps + bonus);
      result = SphereResult(rarity: rarity, bonusSteps: bonus);
    }
    // Remember the payout so today's opened spheres can be summarised below.
    next = next.copyWith(sphereRewards: {
      ...next.sphereRewards,
      tier.id: encodeSphereReward(result),
    });
    state = next;
    _checkTierUp(); // a currency bonus may cross into a new tier
    await _save();
    return result;
  }

  // --- Wearables (character slots) ---
  Future<void> equip(ShopItem item) async {
    if (!state.owned.contains(item.id)) return;
    state = state.copyWith(equipped: {...state.equipped, item.slot: item.id});
    await _save();
  }

  Future<void> unequip(ItemSlot slot) async {
    final next = {...state.equipped}..remove(slot);
    state = state.copyWith(equipped: next);
    await _save();
  }

  // --- Home decor (placed in the room, multiple allowed) ---
  Future<void> placeHome(String itemId) async {
    if (!state.owned.contains(itemId)) return;
    state = state.copyWith(placedHome: {...state.placedHome, itemId});
    await _save();
  }

  Future<void> removeHome(String itemId) async {
    state = state.copyWith(placedHome: {...state.placedHome}..remove(itemId));
    await _save();
  }

  /// Debug helper (Settings): wipe progress.
  Future<void> resetProgress() async {
    state = const PlayerState();
    _lastSyncDate = '';
    await _save();
  }

  /// Dev tool: zero out today's step count without touching lifetime totals
  /// (which stay visible in Statistics). Handy for re-testing the daily cycle.
  ///
  /// Meaningful only while health sync is paused — that's the simulated-testing
  /// mode. (With sync on, the next poll re-reads the real total; we must NOT
  /// touch `_lastSyncDate` here, or that poll would treat the whole day as new
  /// and re-credit it into lifetime.)
  Future<void> resetDailySteps() async {
    state = state.copyWith(todaySteps: 0);
    await _save();
  }
}
