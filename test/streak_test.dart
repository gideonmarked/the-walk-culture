import 'package:flutter_test/flutter_test.dart';
import 'package:step_quest/core/streaks.dart';

void main() {
  group('computeStreak', () {
    test('first goal met starts streak at 1', () {
      final u = computeStreak(
        current: 0,
        best: 0,
        lastMetDate: '',
        today: '2026-7-11',
        yesterday: '2026-7-10',
        goalMet: true,
      );
      expect(u.current, 1);
      expect(u.best, 1);
      expect(u.lastMetDate, '2026-7-11');
    });

    test('consecutive day increments', () {
      final u = computeStreak(
        current: 3,
        best: 3,
        lastMetDate: '2026-7-10',
        today: '2026-7-11',
        yesterday: '2026-7-10',
        goalMet: true,
      );
      expect(u.current, 4);
      expect(u.best, 4);
    });

    test('gap resets to 1 but keeps best', () {
      final u = computeStreak(
        current: 5,
        best: 5,
        lastMetDate: '2026-7-8', // two days ago
        today: '2026-7-11',
        yesterday: '2026-7-10',
        goalMet: true,
      );
      expect(u.current, 1);
      expect(u.best, 5);
    });

    test('already counted today is idempotent', () {
      final u = computeStreak(
        current: 4,
        best: 4,
        lastMetDate: '2026-7-11',
        today: '2026-7-11',
        yesterday: '2026-7-10',
        goalMet: true,
      );
      expect(u.current, 4);
    });

    test('goal not met leaves streak untouched', () {
      final u = computeStreak(
        current: 4,
        best: 6,
        lastMetDate: '2026-7-10',
        today: '2026-7-11',
        yesterday: '2026-7-10',
        goalMet: false,
      );
      expect(u.current, 4);
      expect(u.best, 6);
      expect(u.lastMetDate, '2026-7-10');
    });
  });
}
