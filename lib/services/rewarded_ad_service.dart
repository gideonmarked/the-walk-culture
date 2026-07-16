import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Outcome of trying to show a rewarded ad.
enum AdOutcome {
  /// The user watched to completion — grant the reward.
  earned,

  /// The user closed the ad early — grant nothing.
  dismissed,

  /// No ad could be loaded/shown (no fill, offline, SDK missing).
  failed,
}

/// Shows rewarded video ads. The app codes against this interface so the reward
/// economy is testable and the ad SDK stays swappable.
///
/// The live implementation is [AdMobRewardedAdService] (Google Mobile Ads) —
/// swap it in from `main()` once you've set your AdMob App ID + ad unit. Until
/// then, [StubRewardedAdService] simulates a completed watch so the whole
/// watch-ad → reward flow is exercisable end-to-end without an ad account.
abstract class RewardedAdService {
  /// Show an ad and resolve with the outcome. Never throws — a load/show
  /// failure resolves to [AdOutcome.failed].
  Future<AdOutcome> show();
}

/// Placeholder ad: waits a beat (as if a video were playing) then reports a
/// completed watch. Lets the reward flow be built and demoed before real ads.
class StubRewardedAdService implements RewardedAdService {
  const StubRewardedAdService();

  @override
  Future<AdOutcome> show() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return AdOutcome.earned;
  }
}

/// Swapped from `main()` for the real Google Mobile Ads implementation. Defaults
/// to the stub so nothing depends on the ad SDK being wired first.
final rewardedAdServiceProvider =
    Provider<RewardedAdService>((ref) => const StubRewardedAdService());
