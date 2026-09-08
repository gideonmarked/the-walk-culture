import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/achievements.dart';
import '../core/bible.dart';
import '../core/currency.dart';
import '../core/health.dart';
import '../core/prayer.dart';
import '../core/prayer_requests.dart';
import '../core/premium.dart';
import '../core/quests.dart';
import '../core/social.dart';
import '../core/spheres.dart';
import '../core/notifications.dart';
import '../core/streaks.dart';
import '../core/travel_pass.dart';
import '../data/shop_catalog.dart';
import '../models/player_state.dart';
import '../models/shop_item.dart';
import '../services/cloud/cloud_sync_service.dart';
import '../services/cloud/prayer_request_service.dart';
import '../services/cloud/social_service.dart';
import '../services/health_service.dart';
import 'notifications.dart';
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
  Timer? _socialPoll;
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
    _socialPoll?.cancel();
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
    // Stamp/roll the Travel Pass season before anything can award XP into it.
    // Persist it here: a player who opens the app on rollover day and walks
    // nowhere gets no other save, and the reset would be lost.
    if (_rollSeasonIfNeeded()) await _save();
    // Mint a stable share code on first run. Server-assigned + uniqueness-checked
    // once the backend is live; this local code is what the Profile shows until
    // then (and the seed the server adopts on first sync).
    if (state.accountCode.isEmpty) {
      state = state.copyWith(accountCode: generateCode());
    }
    // doc §2.3: sync on app open — but only if the user hasn't paused sync.
    // Read prefs directly: healthSyncProvider's own load may not have run yet.
    if (prefs.getBool(HealthSyncController.prefsKey) ?? true) {
      await syncSteps();
    }
    startAutoSync(); // then keep it fresh every few seconds while open
    await _maybeGrantVipStipend(); // credit the day's VIP stipend, if owed
    // Publish our code (+ username, if any) so friends can find us by code even
    // when we've never set a username. Best-effort; a no-op offline.
    unawaited(_ref.read(socialServiceProvider).upsertProfile(
        username: state.username, accountCode: state.accountCode));
    _startSocialPolling(); // friend requests / accepts / prayers → notifications
  }

  static const _reqSeenKey = 'twc_friend_reqs_seen_v1';
  static const _accSeenKey = 'twc_friends_accepted_seen_v1';

  /// Poll the social backend on an interval while the app is open, turning new
  /// friend requests, accepts, and prayers into notifications. Cheap when
  /// offline (the service short-circuits to empty without a network call).
  void _startSocialPolling() {
    if (!kEnableBackgroundServices) return;
    _socialPoll?.cancel();
    _checkSocial(); // once now
    _socialPoll =
        Timer.periodic(const Duration(seconds: 20), (_) => _checkSocial());
  }

  Future<void> _checkSocial() async {
    await _checkFriendNotifications();
    await _maybeCheckPrayerSocial();
  }

  /// Notify on friend requests that landed on us and requests of ours that were
  /// accepted. A persisted "seen" set means each is announced exactly once.
  Future<void> _checkFriendNotifications() async {
    final social = _ref.read(socialServiceProvider);
    final incoming = await social.incomingRequests();
    final friends = await social.friends();
    if (incoming.isEmpty && friends.isEmpty) return; // offline or nothing yet

    final prefs = await SharedPreferences.getInstance();

    final seenReq = (prefs.getStringList(_reqSeenKey) ?? const <String>[]).toSet();
    for (final u in incoming) {
      if (seenReq.add(u.id)) {
        _notify(NotifKind.social, 'New friend request',
            '${u.display} wants to be friends. 🤝',
            id: 'friendreq-${u.id}');
      }
    }
    await prefs.setStringList(_reqSeenKey, seenReq.toList());

    final seenAcc = (prefs.getStringList(_accSeenKey) ?? const <String>[]).toSet();
    for (final f in friends.where((f) => f.accepted)) {
      if (seenAcc.add(f.id)) {
        _notify(NotifKind.social, 'Friend added',
            '${f.display} is now your friend. 🎉',
            id: 'friendacc-${f.id}');
      }
    }
    await prefs.setStringList(_accSeenKey, seenAcc.toList());
  }

  /// Mark a friendship as already-announced — called when *I* tap Accept, so the
  /// poller doesn't then notify me about the friend I just added myself.
  Future<void> noteFriendAccepted(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = (prefs.getStringList(_accSeenKey) ?? const <String>[]).toSet();
    seen.add(id);
    await prefs.setStringList(_accSeenKey, seen.toList());
  }

  static const _praySeenKey = 'twc_pray_total_seen_v1';

  /// Surface a social notification when the total prayers across the player's own
  /// shared requests has grown since we last looked. The first run baselines
  /// silently (no notification for prayers that happened before this existed).
  /// Server-backed, so it's a no-op offline — lights up once Supabase is live.
  Future<void> _maybeCheckPrayerSocial() async {
    final svc = _ref.read(prayerRequestServiceProvider);
    if (!svc.online) return;
    final total = await svc.myPrayTotal();
    if (total == null) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_praySeenKey) ?? total; // baseline on first sight
    if (total > seen) {
      final delta = total - seen;
      _notify(
        NotifKind.social,
        'Someone prayed for you',
        delta == 1
            ? 'Someone just prayed for your request. 🙏'
            : '$delta people have prayed for your requests. 🙏',
        id: 'pray-$total',
      );
    }
    await prefs.setInt(_praySeenKey, total);
  }

  /// Re-check for new prayers on your requests (e.g. when returning to the app).
  Future<void> refreshPrayerSocial() => _maybeCheckPrayerSocial();

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
      _notify(NotifKind.reward, 'New tier reached',
          'You banked enough to reach ${kTierNames[idx]}. 🎉',
          id: 'tier-$idx');
    }
  }

  /// Drop an entry into the in-app inbox (mirrored to the phone tray). Stable
  /// [id] dedupes, so re-grading the same milestone won't notify twice.
  void _notify(NotifKind kind, String title, String body,
      {required String id}) {
    _ref.read(notificationsProvider.notifier).add(
          kind: kind,
          title: title,
          body: body,
          id: id,
        );
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
    final previousLevel = state.healthLevel;
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

    // Tell the player how yesterday's walking moved their health, and that a
    // fresh set of daily practices is waiting. Keyed by day so it fires once.
    if (!firstEverDay) {
      if (gradedLevel > previousLevel) {
        _notify(NotifKind.health, 'You climbed a level',
            'Yesterday’s steps lifted you to ${kHealthLevels[gradedLevel].name}. Keep it up! ${kHealthLevels[gradedLevel].emoji}',
            id: 'health-up-$_todayKey');
      } else if (gradedLevel < previousLevel) {
        _notify(NotifKind.health, 'You slipped a level',
            'You’re at ${kHealthLevels[gradedLevel].name} today. A good walk brings you back. ${kHealthLevels[gradedLevel].emoji}',
            id: 'health-down-$_todayKey');
      }
      _notify(NotifKind.devotion, 'A new day of practices',
          'Today’s Bible verse, prayers, and gratitude are ready. 🙏',
          id: 'devotions-$_todayKey');
    }
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
    // Pass XP tracks the steps actually WALKED, not `gained` — VIP/boost
    // multiply currency, never progress on the track.
    _addPassXp(delta > 0 ? delta : 0);
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
    _addPassXp(n); // raw steps, unmultiplied
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
    _addPassXp(kPassXpPerQuest);
    _checkTierUp();
    await _save();
    return true;
  }

  /// Roll a rarity from [odds] and grant a random unowned shop item of that
  /// rarity, or a currency bonus if everything at that rarity is already owned
  /// (same fallback as spheres). Mutates [state]; the caller stamps the claim
  /// date and saves. Shared by the Bible and prayer daily rewards.
  SphereResult _rollAndGrantReward(Map<Rarity, double> odds) {
    // Every daily practice funnels through here, so this is the one place the
    // devotion pass-XP top-up needs to live.
    _addPassXp(kPassXpPerDevotion);
    final rarity = rollRarityFromOdds(odds, _rng.nextDouble());
    final candidates = kRollableCatalog
        .where((i) => i.rarity == rarity && !state.owned.contains(i.id))
        .toList();
    if (candidates.isNotEmpty) {
      final item = candidates[_rng.nextInt(candidates.length)];
      state = state.copyWith(owned: {...state.owned, item.id});
      return SphereResult(rarity: rarity, item: item);
    }
    final bonus = fallbackBonusFor(rarity);
    state = state.copyWith(lifetimeSteps: state.lifetimeSteps + bonus);
    return SphereResult(rarity: rarity, bonusSteps: bonus);
  }

  /// Whether today's Bible-verse reward is still available.
  bool get bibleReadyToday => state.bibleClaimedDate != _todayKey;

  /// Grant the daily Bible-verse reward (rarity from [kBibleRewardOdds]). Once
  /// per day; returns null if already claimed today.
  Future<SphereResult?> claimBibleReward() async {
    _rollDayIfNeeded();
    if (!bibleReadyToday) return null;
    final result = _rollAndGrantReward(kBibleRewardOdds);
    state = state.copyWith(bibleClaimedDate: _todayKey);
    _checkTierUp();
    await _save();
    return result;
  }

  /// Whether today's prayer reward is still available.
  bool get prayerReadyToday => state.prayerClaimedDate != _todayKey;

  /// Grant the daily prayer reward (rarity from [kPrayerRewardOdds], a little
  /// kinder than the Bible read). Once per day; null if already claimed today.
  Future<SphereResult?> claimPrayerReward() async {
    _rollDayIfNeeded();
    if (!prayerReadyToday) return null;
    final result = _rollAndGrantReward(kPrayerRewardOdds);
    state = state.copyWith(prayerClaimedDate: _todayKey);
    _checkTierUp();
    await _save();
    return result;
  }

  /// Whether today's Prayer Walk reward is still available.
  bool get prayerWalkReadyToday => state.prayerWalkClaimedDate != _todayKey;

  /// Grant the daily Prayer Walk reward (rarity from [kPrayerRewardOdds]). Once
  /// per day; null if already claimed today.
  Future<SphereResult?> claimPrayerWalkReward() async {
    _rollDayIfNeeded();
    if (!prayerWalkReadyToday) return null;
    final result = _rollAndGrantReward(kPrayerRewardOdds);
    state = state.copyWith(prayerWalkClaimedDate: _todayKey);
    _checkTierUp();
    await _save();
    return result;
  }

  /// Whether today's Gratitude reward is still available.
  bool get gratitudeReadyToday => state.gratitudeClaimedDate != _todayKey;

  /// Grant the daily Gratitude reward — always a COMMON item (gratitude is the
  /// point, not the loot). Once per day; null if already claimed today.
  Future<SphereResult?> claimGratitudeReward() async {
    _rollDayIfNeeded();
    if (!gratitudeReadyToday) return null;
    final result = _rollAndGrantReward(const {Rarity.common: 100.0});
    state = state.copyWith(gratitudeClaimedDate: _todayKey);
    _checkTierUp();
    await _save();
    return result;
  }

  /// How many of today's request-prayer rewards have already been handed out.
  int get requestPrayersRewardedToday =>
      state.requestPrayerRewardDate == _todayKey
          ? state.requestPrayersRewardedToday
          : 0;

  /// Rewards still available today for praying for a shared request.
  int get requestPrayerRewardsLeft =>
      (kRewardedRequestPrayersPerDay - requestPrayersRewardedToday)
          .clamp(0, kRewardedRequestPrayersPerDay);

  /// Reward for praying for a shared request. Every prayer rewards, but only the
  /// first [kRewardedRequestPrayersPerDay] each day (anti-farm cap). Returns null
  /// once the cap is spent — the prayer still "counts" on the server either way.
  Future<SphereResult?> claimRequestPrayerReward() async {
    _rollDayIfNeeded();
    final rewardedToday = requestPrayersRewardedToday;
    if (rewardedToday >= kRewardedRequestPrayersPerDay) return null;
    final result = _rollAndGrantReward(kRequestPrayerRewardOdds);
    state = state.copyWith(
      requestPrayerRewardDate: _todayKey,
      requestPrayersRewardedToday: rewardedToday + 1,
    );
    _checkTierUp();
    await _save();
    return result;
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
    // Reward-only loot (sphere drops, Travel Pass exclusives) is priced 0, so
    // the tier/price check below would hand it over for nothing. The shop UI
    // already filters these out; this is the rule, not the decoration.
    if (!item.inShop) return false;
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
    final candidates = kRollableCatalog
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
    _addPassXp(kPassXpPerSphere);
    _checkTierUp(); // a currency bonus may cross into a new tier
    await _save();
    return result;
  }

  // --- Travel Pass (core/travel_pass.dart) ---

  /// The season the pass is in right now — derived from the clock, never
  /// stored, so it needs no server to stay in step with everyone else.
  PassSeason get passSeason => seasonAt(DateTime.now());

  /// Level reached on this season's track, 0..[kPassLevelCount].
  int get passLevel => passLevelForXp(state.passXp);

  bool get _isVip => _ref.read(premiumControllerProvider).isVip;

  /// Close out a finished season: the track drops back to level 0 and every
  /// unclaimed reward is gone. The same shape as [_rollDayIfNeeded] — derive
  /// the current season, compare it to the one the saved progress belongs to,
  /// and wipe on a mismatch.
  ///
  /// Returns true when it actually changed state, so the caller knows there's
  /// something to persist. Every other caller is mid-change and saves anyway;
  /// [_init] is the one that would otherwise leave the reset in memory only.
  bool _rollSeasonIfNeeded() {
    final season = passSeason;
    if (state.passSeasonId == season.id) return false;

    // Seasons only ever move FORWARD. A stored season ahead of the derived one
    // therefore means the clock is wrong, not that time passed — a dead RTC, a
    // pre-NTP boot, a factory reset, someone winding the date back. Wiping
    // here would destroy a real season's progress permanently, so sit tight
    // and let the clock catch up.
    final stored = seasonIndexFromId(state.passSeasonId);
    if (stored != null && stored > season.index) return false;

    // '' means this save predates the pass (or is brand new) — stamp the
    // season silently rather than announcing a rollover that never happened.
    final firstEver = state.passSeasonId.isEmpty;
    state = state.copyWith(
      passSeasonId: season.id,
      passXp: 0,
      claimedPassFree: <String>{},
      claimedPassVip: <String>{},
    );
    if (!firstEver) {
      _notify(
          NotifKind.reward,
          'A new Travel Pass season',
          '${season.name} has begun — $kPassLevelCount fresh levels to walk. '
              '${season.emoji}',
          id: 'pass-season-${season.id}');
    }
    return true;
  }

  /// Add pass XP and announce a level-up. Mutates [state] WITHOUT saving —
  /// every caller is already in the middle of a change that saves, and this
  /// riding along keeps steps from writing to disk twice.
  void _addPassXp(int xp) {
    if (xp <= 0) return;
    _rollSeasonIfNeeded();
    final before = passLevel;
    if (before >= kPassLevelCount) return; // track maxed — nothing to bank
    state = state.copyWith(passXp: state.passXp + xp);
    final after = passLevel;
    if (after > before) {
      _notify(
          NotifKind.reward,
          'Travel Pass level $after',
          after >= kPassLevelCount
              ? 'You finished ${passSeason.name}. Claim the last of your rewards! 🏁'
              : 'Level $after is yours — a new reward is waiting on the Pass. 🎁',
          id: 'pass-${state.passSeasonId}-level-$after');
    }
  }

  Set<String> _claims(bool vip) =>
      vip ? state.claimedPassVip : state.claimedPassFree;

  /// Whether [level]'s reward on the given track has already been taken.
  bool passRewardClaimed(int level, {required bool vip}) =>
      _claims(vip).contains('$level');

  /// Whether [level]'s reward can be taken right now: the level is reached, the
  /// cell isn't empty, it isn't already claimed, and — on the VIP track — VIP
  /// is currently active.
  bool passRewardClaimable(int level, {required bool vip}) {
    final entry = passLevelAt(level);
    if (entry == null) return false;
    if ((vip ? entry.vip : entry.free) == null) return false;
    if (passLevel < level) return false;
    if (passRewardClaimed(level, vip: vip)) return false;
    return vip ? _isVip : true;
  }

  /// How many rewards are sitting there unclaimed — drives the nav-bar badge.
  int get passClaimableCount {
    var n = 0;
    for (var level = 1; level <= kPassLevelCount; level++) {
      if (passRewardClaimable(level, vip: false)) n++;
      if (passRewardClaimable(level, vip: true)) n++;
    }
    return n;
  }

  /// Grant one cell. Mutates [state] and stamps the claim; the caller saves.
  /// Returns null when it wasn't claimable, so a double-tap can't pay twice.
  PassReward? _takePassReward(int level, {required bool vip}) {
    if (!passRewardClaimable(level, vip: vip)) return null;
    final entry = passLevelAt(level)!;
    final reward = (vip ? entry.vip : entry.free)!;

    // Stamp first: if anything below throws, the reward is spent rather than
    // repeatable.
    if (vip) {
      state = state.copyWith(claimedPassVip: {...state.claimedPassVip, '$level'});
    } else {
      state =
          state.copyWith(claimedPassFree: {...state.claimedPassFree, '$level'});
    }

    switch (reward.kind) {
      case PassRewardKind.pebbles:
        // Spendable only, exactly like an IAP or ad grant — pass rewards never
        // touch todaySteps or the health ladder.
        state = state.copyWith(lifetimeSteps: state.lifetimeSteps + reward.amount);
      case PassRewardKind.item:
        state = state.copyWith(owned: {...state.owned, reward.itemId});
      case PassRewardKind.boost:
        // Extend from the later of now/current expiry so claiming a boost while
        // one is already running stacks instead of throwing the remainder away
        // (activateBoost overwrites; a reward you've earned shouldn't).
        final now = DateTime.now().millisecondsSinceEpoch;
        final base = state.boostUntilMs > now ? state.boostUntilMs : now;
        state = state.copyWith(
            boostUntilMs: base + reward.hours * Duration.millisecondsPerHour);
    }
    return reward;
  }

  /// Claim one reward. Null if it wasn't available (not reached, already taken,
  /// empty cell, or the VIP track without VIP).
  Future<PassReward?> claimPassReward(int level, {required bool vip}) async {
    final rolled = _rollSeasonIfNeeded();
    final reward = _takePassReward(level, vip: vip);
    if (reward == null) {
      if (rolled) await _save(); // don't drop a rollover on a refused claim
      return null;
    }
    _checkTierUp();
    await _save();
    return reward;
  }

  /// Sweep up everything claimable in one pass — including the whole VIP column
  /// earned before subscribing, which is the point of the retro-claim rule.
  /// One save for the lot.
  Future<List<PassReward>> claimAllPassRewards() async {
    final rolled = _rollSeasonIfNeeded();
    final claimed = <PassReward>[];
    for (var level = 1; level <= kPassLevelCount; level++) {
      for (final vip in const [false, true]) {
        final reward = _takePassReward(level, vip: vip);
        if (reward != null) claimed.add(reward);
      }
    }
    if (claimed.isEmpty) {
      if (rolled) await _save();
      return claimed;
    }
    _checkTierUp();
    await _save();
    return claimed;
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
  /// Set the player's chosen display name. Server enforces uniqueness once live;
  /// locally we just trim and store it.
  Future<void> setUsername(String name) async {
    state = state.copyWith(username: name.trim());
    await _save();
  }

  Future<void> resetProgress() async {
    // Keep the share code stable across a dev reset so friends' links don't
    // break; a fresh code is only minted when there's genuinely none.
    final keptCode = state.accountCode;
    state = PlayerState(accountCode: keptCode);
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
