import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/social.dart';
import 'package:step_quest/state/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('share codes', () {
    test('generates 7 chars from the unambiguous alphabet', () {
      final rng = Random(42);
      for (var i = 0; i < 200; i++) {
        final code = generateCode(rng);
        expect(code.length, kCodeLength);
        for (final ch in code.split('')) {
          expect(kCodeAlphabet.contains(ch), isTrue, reason: 'stray char $ch');
        }
        // Never contains the look-alikes we excluded.
        expect(code.contains(RegExp('[01OIL]')), isFalse);
      }
    });

    test('validates and normalises like the example', () {
      expect(isValidCode('A7A43B7'), isTrue);
      expect(isValidCode('a7a43b7'), isTrue); // case-insensitive
      expect(isValidCode(' A7A43B7 '), isTrue); // trims
      expect(normalizeCode(' a7a43b7 '), 'A7A43B7');

      expect(isValidCode('A7A43B'), isFalse); // too short
      expect(isValidCode('A7A43B77'), isFalse); // too long
      expect(isValidCode('A7A43B0'), isFalse); // 0 is not in the alphabet
      expect(isValidCode('A7A43B!'), isFalse); // symbol
    });
  });

  group('group slot cost curve', () {
    test('first group is free, then it escalates and doubles', () {
      expect(groupSlotCost(0), 0); // 1st free
      expect(groupSlotCost(1), 50000); // 2nd
      expect(groupSlotCost(2), 200000); // 3rd
      expect(groupSlotCost(3), 500000); // 4th
      expect(groupSlotCost(4), 1000000); // 5th — doubles from 4th
      expect(groupSlotCost(5), 2000000); // 6th
    });

    test('is monotonically non-decreasing (never gets cheaper)', () {
      var prev = -1;
      for (var n = 0; n < 8; n++) {
        final c = groupSlotCost(n);
        expect(c, greaterThanOrEqualTo(prev));
        prev = c;
      }
    });
  });

  test('account code is minted once and stays stable', () async {
    kEnableBackgroundServices = false;
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final code = container.read(playerControllerProvider).accountCode;
    expect(isValidCode(code), isTrue);

    // Setting a username or resetting progress does not change the code.
    await controller.setUsername('StrollKing');
    expect(container.read(playerControllerProvider).accountCode, code);

    await controller.resetProgress();
    expect(container.read(playerControllerProvider).accountCode, code);
    expect(container.read(playerControllerProvider).username, ''); // wiped
  });
}
