/// AdMob identifiers and the test-vs-real gate.
///
/// SAFETY: tapping your OWN real ads is the fastest way to get an AdMob account
/// banned. So every build serves Google's TEST rewarded ad (a real video, but
/// unbillable) unless it was compiled with `--dart-define=REAL_ADS=true`. Your
/// real unit only goes live in the production build:
///
///   flutter build apk --release --dart-define=DEV_TOOLS=true   # test ads
///   flutter build appbundle --release --dart-define=REAL_ADS=true  # real ads
///
/// The AdMob App ID lives in AndroidManifest.xml, not here.
library;

/// Whether to serve real ads. Default false = test ads (safe during dev).
const bool kUseRealAds = bool.fromEnvironment('REAL_ADS');

/// Google's official test rewarded unit — always serves test ads on any device,
/// no account or test-device registration needed.
const String _testRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// The app's real rewarded unit (AdMob → The Walk Culture → Ad units).
const String _realRewardedUnitId = 'ca-app-pub-8276197101210812/3733785898';

String get rewardedAdUnitId =>
    kUseRealAds ? _realRewardedUnitId : _testRewardedUnitId;
