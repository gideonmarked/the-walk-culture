// Optional account linking (Google / Apple): hidden when unconfigured, and a
// switch of account clears progress without sending the player back through
// onboarding.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/features/settings/account_link_tile.dart';
import 'package:step_quest/services/cloud/account_link_service.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  test('nothing is offered when the build has no backend', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      expect(container.read(accountLinkServiceProvider).availableProviders,
          isEmpty,
          reason: '$platform');
      expect(container.read(accountLinkServiceProvider).linkedLabel, isNull);
      container.dispose();
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('Apple and Google map to the matching Supabase providers', () {
    expect(SignInProvider.apple.supabase.name, 'apple');
    expect(SignInProvider.google.supabase.name, 'google');
  });

  testWidgets('the Settings section is hidden when unavailable', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: AccountLinkTile())),
    ));
    expect(find.text('Back up your progress'), findsNothing);
  });

  test('switching accounts clears progress but keeps onboarding and sync setting',
      () async {
    SharedPreferences.setMockInitialValues({
      'stepquest_player_v1': '{"lifetimeSteps": 50000}',
      'twc_gratitude_v1': '[]',
      OnboardingController.prefsKey: true,
      HealthSyncController.prefsKey: false,
    });

    await AccountLinkService.clearLocalProgress();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(),
        {OnboardingController.prefsKey, HealthSyncController.prefsKey});
    expect(prefs.getBool(OnboardingController.prefsKey), isTrue);
    expect(prefs.getBool(HealthSyncController.prefsKey), isFalse);
  });
}
