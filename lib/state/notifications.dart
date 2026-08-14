import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications.dart';
import '../services/local_notification_service.dart';

/// The in-app notification inbox. Persists locally (like the gratitude journal —
/// its own key, never synced), keeps the newest [_cap] entries, and mirrors each
/// new one to the phone tray via [LocalNotificationService].
class NotificationsController extends StateNotifier<List<AppNotification>> {
  NotificationsController() : super(const []) {
    _load();
  }

  static const _prefsKey = 'twc_notifications_v1';
  static const _cap = 50;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      state = list;
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode([for (final n in state) n.toJson()]));
  }

  /// Add a notification. [id] must be stable for a given event so it can't be
  /// added twice (a re-check of the same milestone is a no-op). Returns true if
  /// it was actually added. Set [tray] false to record it silently in-app only.
  bool add({
    required NotifKind kind,
    required String title,
    required String body,
    required String id,
    bool tray = true,
  }) {
    if (state.any((n) => n.id == id)) return false;
    final n = AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    state = [n, ...state].take(_cap).toList();
    _save();
    if (tray) LocalNotificationService.show(title, body);
    return true;
  }

  void markAllRead() {
    if (state.every((n) => n.read)) return;
    state = [for (final n in state) n.copyWith(read: true)];
    _save();
  }

  void remove(String id) {
    state = [for (final n in state) if (n.id != id) n];
    _save();
  }

  void clear() {
    if (state.isEmpty) return;
    state = const [];
    _save();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, List<AppNotification>>(
  (ref) => NotificationsController(),
);

/// Unread badge count for the app-bar bell.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.read).length;
});
