import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/premium.dart';
import '../core/streaks.dart' show dayKey;
import '../services/cloud/cloud_sync_service.dart';

/// The player's monetization entitlements — VIP window, daily-stipend bookkeeping,
/// and the rewarded-ad counter. Kept SEPARATE from PlayerState (gameplay), the
/// same way onboarding/health-sync are, so billing concerns don't tangle into
/// the wallet.
///
/// This is the LOCAL mirror. In production it's a cache of the server's record:
/// after a store purchase is validated server-side, the backend is the source of
/// truth for `vipUntilMs`, and this local copy is refreshed from it on launch.
class PremiumState {
  const PremiumState({
    this.vipUntilMs = 0,
    this.adRewardsToday = 0,
    this.adRewardsDay = '',
    this.stipendDay = '',
    this.purchasedStepsTotal = 0,
    this.adStepsTotal = 0,
    this.fulfilledPurchases = const [],
  });

  /// VIP is active until this epoch-millis (0 = never subscribed).
  final int vipUntilMs;

  /// Rewarded ads watched today, and the day-key that count belongs to.
  final int adRewardsToday;
  final String adRewardsDay;

  /// The last day the VIP stipend was credited (so it lands once per day).
  final String stipendDay;

  /// Lifetime totals, for the stats screen and honest analytics.
  final int purchasedStepsTotal;
  final int adStepsTotal;

  /// Store purchases already credited to the wallet, by order id — newest
  /// last, capped at [kMaxFulfilledPurchases]. Play can deliver the same
  /// purchase more than once (a restore, a relaunch before it was finished),
  /// and each delivery must credit at most once.
  final List<String> fulfilledPurchases;

  static const kMaxFulfilledPurchases = 200;

  bool get isVip => vipUntilMs > DateTime.now().millisecondsSinceEpoch;

  /// Days of VIP left, rounded up (0 when not a VIP).
  int get vipDaysLeft {
    if (!isVip) return 0;
    final ms = vipUntilMs - DateTime.now().millisecondsSinceEpoch;
    return (ms / Duration.millisecondsPerDay).ceil();
  }

  int get adRewardLimit =>
      kAdRewardsPerDay + (isVip ? kVipExtraAdsPerDay : 0);

  PremiumState copyWith({
    int? vipUntilMs,
    int? adRewardsToday,
    String? adRewardsDay,
    String? stipendDay,
    int? purchasedStepsTotal,
    int? adStepsTotal,
    List<String>? fulfilledPurchases,
  }) =>
      PremiumState(
        vipUntilMs: vipUntilMs ?? this.vipUntilMs,
        adRewardsToday: adRewardsToday ?? this.adRewardsToday,
        adRewardsDay: adRewardsDay ?? this.adRewardsDay,
        stipendDay: stipendDay ?? this.stipendDay,
        purchasedStepsTotal: purchasedStepsTotal ?? this.purchasedStepsTotal,
        adStepsTotal: adStepsTotal ?? this.adStepsTotal,
        fulfilledPurchases: fulfilledPurchases ?? this.fulfilledPurchases,
      );

  Map<String, dynamic> toJson() => {
        'vipUntilMs': vipUntilMs,
        'adRewardsToday': adRewardsToday,
        'adRewardsDay': adRewardsDay,
        'stipendDay': stipendDay,
        'purchasedStepsTotal': purchasedStepsTotal,
        'adStepsTotal': adStepsTotal,
        'fulfilledPurchases': fulfilledPurchases,
      };

  factory PremiumState.fromJson(Map<String, dynamic> j) => PremiumState(
        vipUntilMs: (j['vipUntilMs'] as num?)?.toInt() ?? 0,
        adRewardsToday: (j['adRewardsToday'] as num?)?.toInt() ?? 0,
        adRewardsDay: (j['adRewardsDay'] as String?) ?? '',
        stipendDay: (j['stipendDay'] as String?) ?? '',
        purchasedStepsTotal: (j['purchasedStepsTotal'] as num?)?.toInt() ?? 0,
        adStepsTotal: (j['adStepsTotal'] as num?)?.toInt() ?? 0,
        fulfilledPurchases:
            (j['fulfilledPurchases'] as List?)?.cast<String>() ?? const [],
      );
}

final premiumControllerProvider =
    StateNotifierProvider<PremiumController, PremiumState>(
        (ref) => PremiumController(ref));

class PremiumController extends StateNotifier<PremiumState> {
  PremiumController(this._ref) : super(const PremiumState()) {
    _load();
  }

  final Ref _ref;
  static const _key = 'stepquest_premium_v1';

  /// Bumped by every VIP grant, so a server read that started before a grant
  /// can tell its answer is stale and must not overwrite it.
  int _vipWrites = 0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = PremiumState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {/* keep defaults on a corrupt save */}
    }
    await refreshEntitlementFromServer();
  }

  /// Pull VIP from the backend, which is the source of truth once configured —
  /// the local copy is only a cache so the UI has something before the network
  /// answers. No-op offline/unconfigured, so local VIP survives.
  Future<void> refreshEntitlementFromServer() async {
    final cloud = _ref.read(cloudSyncProvider);
    if (!cloud.isReady) return;
    final writesBefore = _vipWrites;
    final result = await cloud.fetchVipUntil();
    // A failed read says nothing about VIP — keep what we have. Only a real
    // answer may clear it.
    if (result.failed) return;
    // A purchase validated while this read was in flight is newer than it.
    if (_vipWrites != writesBefore) return;
    // "No row" means never subscribed — trust it and clear any stale local
    // VIP, otherwise a wiped/refunded subscription would linger.
    state = state.copyWith(vipUntilMs: result.value?.millisecondsSinceEpoch ?? 0);
    await _save();
  }

  /// Adopt the expiry the server just granted for a validated subscription.
  /// The server's value is absolute (Google's expiry), so applying it twice is
  /// harmless; a later local expiry — another plan — is kept.
  Future<void> setVipUntil(DateTime until) async {
    _vipWrites++;
    final ms = until.millisecondsSinceEpoch;
    if (ms > state.vipUntilMs) state = state.copyWith(vipUntilMs: ms);
    await _save();
  }

  /// Claim [purchaseKey] for crediting. True exactly once per key; the claim
  /// lands in state synchronously, so two deliveries racing each other can't
  /// both see "not yet credited".
  bool markPurchaseFulfilled(String purchaseKey) {
    if (state.fulfilledPurchases.contains(purchaseKey)) return false;
    final keys = [...state.fulfilledPurchases, purchaseKey];
    final overflow = keys.length - PremiumState.kMaxFulfilledPurchases;
    state = state.copyWith(
        fulfilledPurchases: overflow > 0 ? keys.sublist(overflow) : keys);
    _save();
    return true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  String get _today => dayKey(DateTime.now());

  /// Extend VIP by [days] from whichever is later — now, or the current expiry —
  /// so renewals stack rather than reset. Called AFTER a subscription purchase
  /// has been validated (server-side in production).
  Future<void> grantVip(int days) async {
    _vipWrites++;
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = state.vipUntilMs > now ? state.vipUntilMs : now;
    state = state.copyWith(
      vipUntilMs: base + days * Duration.millisecondsPerDay,
    );
    await _save();
  }

  /// Debug/testing helper to end VIP immediately.
  Future<void> clearVip() async {
    state = state.copyWith(vipUntilMs: 0);
    await _save();
  }

  /// Whether the player can watch another rewarded ad today.
  bool get canWatchAd {
    final todayCount = state.adRewardsDay == _today ? state.adRewardsToday : 0;
    return todayCount < state.adRewardLimit;
  }

  int get adsWatchedToday =>
      state.adRewardsDay == _today ? state.adRewardsToday : 0;

  /// Record that a rewarded ad paid out. Returns false (no-op) if the daily cap
  /// is already hit — the caller grants the currency only when this returns true.
  bool recordAdReward() {
    if (!canWatchAd) return false;
    final newDay = state.adRewardsDay != _today;
    state = state.copyWith(
      adRewardsToday: (newDay ? 0 : state.adRewardsToday) + 1,
      adRewardsDay: _today,
      adStepsTotal: state.adStepsTotal + kAdRewardSteps,
    );
    _save();
    return true;
  }

  /// Record a currency-pack purchase (for stats). The actual wallet credit is
  /// done by the PlayerController; this just tracks the lifetime total.
  Future<void> recordPurchasedSteps(int steps) async {
    state = state.copyWith(
        purchasedStepsTotal: state.purchasedStepsTotal + steps);
    await _save();
  }

  /// Whether today's VIP stipend is still owed. False when not VIP.
  bool get stipendDueToday => state.isVip && state.stipendDay != _today;

  /// Mark today's stipend as paid (the credit itself is the PlayerController's).
  Future<void> markStipendPaid() async {
    state = state.copyWith(stipendDay: _today);
    await _save();
  }
}
