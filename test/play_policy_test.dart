// Google Play policy requirements: subscription terms, account deletion, and
// accepting the community terms before posting content others can see.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/links.dart';
import 'package:step_quest/core/premium.dart';
import 'package:step_quest/features/safety/community_terms.dart';
import 'package:step_quest/services/cloud/account_service.dart';

void main() {
  group('subscription terms', () {
    test('every VIP plan names its renewal period', () {
      final periods = {for (final p in kVipPlans) p.id: p.periodLabel};
      expect(periods, {
        'vip_weekly': 'week',
        'vip_monthly': 'month',
        'vip_annual': 'year',
      });
    });

    test('terms say it auto-renews and how to cancel, per store', () {
      final android = vipTermsText(ios: false);
      expect(android, contains('auto-renewing'));
      expect(android, contains('Cancel any time in Google Play'));

      final ios = vipTermsText(ios: true);
      expect(ios, contains('auto-renewing'));
      expect(ios, contains('your Apple ID'));
      expect(ios, contains('Subscriptions'));
      expect(ios, isNot(contains('Google Play')));
    });
  });

  test('policy pages are public https links on the project site', () {
    for (final url in [kPrivacyPolicyUrl, kTermsUrl, kDeleteAccountUrl]) {
      expect(url, startsWith('https://'));
      expect(url, startsWith(kSiteBase));
    }
  });

  test('deleting the account wipes everything stored on the phone', () async {
    SharedPreferences.setMockInitialValues({
      'stepquest_player_v1': '{}',
      'twc_gratitude_v1': '[]',
      kCommunityTermsKey: true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // No backend in tests, so this exercises the local-only path.
    final error = await container.read(accountServiceProvider).deleteAccount();

    expect(error, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  group('community terms', () {
    Future<bool?> openGate(WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await ensureCommunityTermsAccepted(context),
            child: const Text('post'),
          ),
        ),
      ));
      await tester.tap(find.text('post'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Continue stays disabled until the player agrees',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openGate(tester);

      FilledButton button() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
      expect(button().onPressed, isNull);

      await tester.tap(find.text('I agree to the terms of use'));
      await tester.pump();
      expect(button().onPressed, isNotNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kCommunityTermsKey), isTrue);
    });

    testWidgets('cancelling blocks the post and remembers nothing',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openGate(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kCommunityTermsKey), isNull);
    });

    testWidgets('once accepted, it is not asked again', (tester) async {
      SharedPreferences.setMockInitialValues({kCommunityTermsKey: true});
      final result = await openGate(tester);
      expect(result, isTrue);
      expect(find.text('Community rules'), findsNothing);
    });
  });
}
