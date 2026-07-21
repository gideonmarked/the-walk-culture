import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR / ePrivacy ad-consent via Google's User Messaging Platform (UMP).
///
/// Before serving ads to users in the EEA / UK (and some US states), the law
/// requires a certified consent dialog. UMP ships inside google_mobile_ads, so
/// there's no extra dependency. Flow: ask UMP whether consent is required for
/// this user's region, show the form if so, and only then request ads. Outside
/// regulated regions UMP reports "not required" and nothing is shown.
///
/// To SEE the EEA form on a non-EEA test device, build with
/// `--dart-define=FORCE_EEA_CONSENT=true` and pass your device's UMP test id via
/// `--dart-define=CONSENT_TEST_DEVICE=<hashed-id>` (it's printed in logcat on
/// the first ad request).
class ConsentService {
  const ConsentService._();

  static const _forceEea = bool.fromEnvironment('FORCE_EEA_CONSENT');
  static const _testDeviceId = String.fromEnvironment('CONSENT_TEST_DEVICE');

  static bool _done = false;

  /// Whether the ads SDK is currently allowed to request ads. False until
  /// consent is resolved; ad code checks this before loading.
  static Future<bool> canRequestAds() =>
      ConsentInformation.instance.canRequestAds();

  /// Resolve consent once per launch. Never throws — on any error it completes
  /// so startup is never blocked (ads are then gated by [canRequestAds]).
  static Future<void> ensure() async {
    if (_done) return;
    _done = true;

    ConsentDebugSettings? debug;
    if (_forceEea) {
      debug = ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: [if (_testDeviceId.isNotEmpty) _testDeviceId],
      );
    }
    final params = ConsentRequestParameters(consentDebugSettings: debug);

    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
              if (e != null) debugPrint('consent form: ${e.message}');
              if (!done.isCompleted) done.complete();
            });
          } else {
            if (!done.isCompleted) done.complete();
          }
        } catch (e) {
          debugPrint('consent flow failed: $e');
          if (!done.isCompleted) done.complete();
        }
      },
      (FormError e) {
        debugPrint('consent info update failed: ${e.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }
}
