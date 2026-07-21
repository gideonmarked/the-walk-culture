import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_config.dart';

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

/// Real rewarded ads via Google Mobile Ads. Loads an ad on demand, shows it,
/// and reports whether the user earned the reward. Never throws — a load or show
/// failure resolves to [AdOutcome.failed], so the reward flow degrades cleanly
/// (offline, no fill, etc.). Serves test or real ads per [rewardedAdUnitId].
class AdMobRewardedAdService implements RewardedAdService {
  const AdMobRewardedAdService();

  @override
  Future<AdOutcome> show() {
    final completer = Completer<AdOutcome>();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(
                    earned ? AdOutcome.earned : AdOutcome.dismissed);
              }
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(AdOutcome.failed);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (err) {
          if (!completer.isCompleted) completer.complete(AdOutcome.failed);
        },
      ),
    );
    return completer.future;
  }
}

/// Real ads by default. The reward economy behind it (daily cap, crediting,
/// server-side ad-reward check) is unchanged — only the ad itself is now real.
final rewardedAdServiceProvider =
    Provider<RewardedAdService>((ref) => const AdMobRewardedAdService());
