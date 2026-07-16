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
  }) =>
      PremiumState(
        vipUntilMs: vipUntilMs ?? this.vipUntilMs,
        adRewardsToday: adRewardsToday ?? this.adRewardsToday,
        adRewardsDay: adRewardsDay ?? this.adRewardsDay,
        stipendDay: stipendDay ?? this.stipendDay,
        purchasedStepsTotal: purchasedStepsTotal ?? this.purchasedStepsTotal,
        adStepsTotal: adStepsTotal ?? this.adStepsTotal,
      );

  Map<String, dynamic> toJson() => {
        'vipUntilMs': vipUntilMs,
        'adRewardsToday': adRewardsToday,
        'adRewardsDay': adRewardsDay,
        'stipendDay': stipendDay,
        'purchasedStepsTotal': purchasedStepsTotal,
        'adStepsTotal': adStepsTotal,
      };

  factory PremiumState.fromJson(Map<String, dynamic> j) => PremiumState(
        vipUntilMs: (j['vipUntilMs'] as num?)?.toInt() ?? 0,
        adRewardsToday: (j['adRewardsToday'] as num?)?.toInt() ?? 0,
        adRewardsDay: (j['adRewardsDay'] as String?) ?? '',
        stipendDay: (j['stipendDay'] as String?) ?? '',
        purchasedStepsTotal: (j['purchasedStepsTotal'] as num?)?.toInt() ?? 0,
        adStepsTotal: (j['adStepsTotal'] as num?)?.toInt() ?? 0,
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
    final until = await cloud.fetchVipUntil();
    // A null server value means "never subscribed" — trust it and clear any
    // stale local VIP, otherwise a wiped/refunded subscription would linger.
    state = state.copyWith(vipUntilMs: until?.millisecondsSinceEpoch ?? 0);
    await _save();
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
