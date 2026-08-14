import 'package:flutter/material.dart';

/// The kind of thing a notification is about — drives its icon/tint and lets the
/// UI group or filter later.
enum NotifKind { system, social, health, reward, streak, trophy, devotion }

extension NotifKindVisuals on NotifKind {
  IconData get icon {
    switch (this) {
      case NotifKind.system:
        return Icons.campaign_outlined;
      case NotifKind.social:
        return Icons.volunteer_activism_outlined;
      case NotifKind.health:
        return Icons.directions_walk_outlined;
      case NotifKind.reward:
        return Icons.card_giftcard_outlined;
      case NotifKind.streak:
        return Icons.local_fire_department_outlined;
      case NotifKind.trophy:
        return Icons.emoji_events_outlined;
      case NotifKind.devotion:
        return Icons.menu_book_outlined;
    }
  }
}

NotifKind _kindFromName(String? name) => NotifKind.values.firstWhere(
      (k) => k.name == name,
      orElse: () => NotifKind.system,
    );

/// One entry in the in-app inbox. Also the payload mirrored to the phone tray.
/// [id] is stable so the same event can't be added twice (see
/// NotificationsController.add).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAtMs,
    this.read = false,
  });

  final String id;
  final NotifKind kind;
  final String title;
  final String body;
  final int createdAtMs;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAtMs: createdAtMs,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'createdAtMs': createdAtMs,
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: _kindFromName(j['kind'] as String?),
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
        read: j['read'] as bool? ?? false,
      );
}

/// "3m ago", "2h ago", "Yesterday", or a date — for the inbox list.
String relativeTime(int createdAtMs, [DateTime? now]) {
  final then = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final d = (now ?? DateTime.now()).difference(then);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'Yesterday';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${then.year}-${then.month.toString().padLeft(2, '0')}-'
      '${then.day.toString().padLeft(2, '0')}';
}
