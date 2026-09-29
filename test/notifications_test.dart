import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_quest/core/notifications.dart';
import 'package:step_quest/state/notifications.dart';

void main() {
  test('add dedupes by id and tracks unread', () async {
    SharedPreferences.setMockInitialValues({});
    final c = NotificationsController();

    expect(c.add(kind: NotifKind.system, title: 'A', body: 'a', id: 'x'), isTrue);
    // Same id is a no-op — re-checking a milestone can't notify twice.
    expect(c.add(kind: NotifKind.system, title: 'A2', body: 'a2', id: 'x'),
        isFalse);
    expect(c.state.length, 1);
    expect(c.state.single.read, isFalse);

    c.markAllRead();
    expect(c.state.single.read, isTrue);
  });

  test('keeps only the newest 50', () async {
    SharedPreferences.setMockInitialValues({});
    final c = NotificationsController();
    for (var i = 0; i < 60; i++) {
      c.add(kind: NotifKind.reward, title: 't$i', body: 'b$i', id: 'n$i');
    }
    expect(c.state.length, 50);
    // Newest is first; the 10 oldest were dropped.
    expect(c.state.first.id, 'n59');
    expect(c.state.any((n) => n.id == 'n0'), isFalse);
  });

  test('persists across controller instances', () async {
    SharedPreferences.setMockInitialValues({});
    NotificationsController()
        .add(kind: NotifKind.social, title: 'Prayed', body: '🙏', id: 'keep');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final reloaded = NotificationsController();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reloaded.state.any((n) => n.id == 'keep'), isTrue);
  });

  test('relativeTime buckets sensibly', () {
    final now = DateTime(2026, 7, 24, 12, 0);
    int ms(Duration ago) => now.subtract(ago).millisecondsSinceEpoch;
    expect(relativeTime(ms(const Duration(seconds: 10)), now), 'Just now');
    expect(relativeTime(ms(const Duration(minutes: 5)), now), '5m ago');
    expect(relativeTime(ms(const Duration(hours: 3)), now), '3h ago');
    expect(relativeTime(ms(const Duration(days: 1)), now), 'Yesterday');
  });
}
