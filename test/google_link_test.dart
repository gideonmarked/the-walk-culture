// Optional Google account linking: hidden when unconfigured, and a switch of
// account clears progress without sending the player back through onboarding.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/features/settings/google_account_tile.dart';
import 'package:step_quest/services/cloud/google_link_service.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  test('not offered when the build has no backend or Google client id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(googleLinkServiceProvider).available, isFalse);
    expect(container.read(googleLinkServiceProvider).linkedEmail, isNull);
  });

  testWidgets('the Settings row is hidden when unavailable', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: GoogleAccountTile())),
    ));
    expect(find.text('Link Google account'), findsNothing);
  });

  test('switching accounts clears progress but keeps onboarding and sync setting',
      () async {
    SharedPreferences.setMockInitialValues({
      'stepquest_player_v1': '{"lifetimeSteps": 50000}',
      'twc_gratitude_v1': '[]',
      OnboardingController.prefsKey: true,
      HealthSyncController.prefsKey: false,
    });

    await GoogleLinkService.clearLocalProgress();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(),
        {OnboardingController.prefsKey, HealthSyncController.prefsKey});
    expect(prefs.getBool(OnboardingController.prefsKey), isTrue);
    expect(prefs.getBool(HealthSyncController.prefsKey), isFalse);
  });
}
