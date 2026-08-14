import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper over flutter_local_notifications that mirrors an in-app inbox
/// entry to the phone's notification tray. Static + best-effort: it swallows its
/// own errors and no-ops until [initialize] has run, so nothing here can block
/// launch or break a unit test (the plugin is never touched before init).
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _nextId = 0;

  static const _channelId = 'twc_general';
  static const _channelName = 'General';
  static const _channelDescription =
      'Milestones, rewards, and prayer activity from The Walk Culture.';

  /// Initialise the plugin + Android channel and ask (once) for the Android 13+
  /// POST_NOTIFICATIONS permission. Safe to call on every launch.
  static Future<void> initialize() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);

      final android13 = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android13 != null) {
        await android13.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
        await android13.requestNotificationsPermission();
      }
      _ready = true;
    } catch (e) {
      debugPrint('LocalNotificationService.initialize failed: $e');
    }
  }

  /// Pop a tray notification. No-op if the plugin isn't ready or the user denied
  /// the permission (the entry still lives in the in-app inbox regardless).
  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      await _plugin.show(_nextId++, title, body, details);
    } catch (e) {
      debugPrint('LocalNotificationService.show failed: $e');
    }
  }
}
