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
/// The AdMob App ID lives in AndroidManifest.xml (Android) and
/// ios/Flutter/AppConfig.xcconfig (iOS), not here.
library;

import 'package:flutter/foundation.dart';

/// Whether to serve real ads. Default false = test ads (safe during dev).
const bool kUseRealAds = bool.fromEnvironment('REAL_ADS');

/// Google's official test rewarded units — always serve test ads on any
/// device, no account or test-device registration needed.
const String _testRewardedUnitAndroid = 'ca-app-pub-3940256099942544/5224354917';
const String _testRewardedUnitIos = 'ca-app-pub-3940256099942544/1712485313';

/// The app's real Android rewarded unit (AdMob → The Walk Culture → Ad units).
const String _realRewardedUnitAndroid = 'ca-app-pub-8276197101210812/3733785898';

/// The real iOS rewarded unit. AdMob issues separate units per platform, so
/// register the iOS app in AdMob and pass its unit at build time:
///   --dart-define=ADMOB_IOS_REWARDED_UNIT=ca-app-pub-XXXX/YYYY
/// Until then an iOS build with REAL_ADS still serves test ads.
const String _realRewardedUnitIos = String.fromEnvironment('ADMOB_IOS_REWARDED_UNIT');

String get rewardedAdUnitId {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return kUseRealAds && _realRewardedUnitIos.isNotEmpty
        ? _realRewardedUnitIos
        : _testRewardedUnitIos;
  }
  return kUseRealAds ? _realRewardedUnitAndroid : _testRewardedUnitAndroid;
}
