/// Player-submitted feedback — bug reports and feature ideas.
///
/// Built for the beta: a report is written to the device FIRST and sent
/// afterwards, because testers hit bugs exactly when the network (or the app)
/// is misbehaving, and a report lost to a bad connection is the one you most
/// needed to read.
library;

import 'package:flutter/material.dart';

/// Body length cap. Generous — a good bug report needs room for steps to
/// reproduce. Mirrored in supabase/feedback.sql.
const int kFeedbackMaxChars = 1000;

/// Optional contact field cap.
const int kFeedbackContactMaxChars = 120;

enum FeedbackKind { bug, idea, other }

extension FeedbackKindLabel on FeedbackKind {
  String get label => switch (this) {
        FeedbackKind.bug => 'Something broke',
        FeedbackKind.idea => 'Feature idea',
        FeedbackKind.other => 'Something else',
      };

  /// The short form, for chips and the history list.
  String get shortLabel => switch (this) {
        FeedbackKind.bug => 'Bug',
        FeedbackKind.idea => 'Idea',
        FeedbackKind.other => 'Other',
      };

  IconData get icon => switch (this) {
        FeedbackKind.bug => Icons.bug_report_outlined,
        FeedbackKind.idea => Icons.lightbulb_outline,
        FeedbackKind.other => Icons.chat_bubble_outline,
      };

  /// What goes on the wire / in the database.
  String get wire => name;
}

FeedbackKind feedbackKindFromName(String? name) => FeedbackKind.values
    .firstWhere((k) => k.name == name, orElse: () => FeedbackKind.other);

/// Where a report is in its life: queued on the device, or accepted by the
/// server. There is deliberately no `failed` — a send that doesn't land stays
/// [pending] and is retried, so nothing is ever quietly dropped.
enum FeedbackStatus { pending, sent }

/// One report, as stored on the device.
@immutable
class FeedbackReport {
  const FeedbackReport({
    required this.id,
    required this.kind,
    required this.body,
    required this.createdAtMs,
    this.contact = '',
    this.diagnostics = const {},
    this.status = FeedbackStatus.pending,
    this.lastError = '',
  });

  /// Client-generated id. Sent along so a retry after a timeout that actually
  /// succeeded can't file the same report twice — the server dedupes on it.
  final String id;

  final FeedbackKind kind;
  final String body;
  final int createdAtMs;

  /// Only what the player typed. Empty means "no reply wanted".
  final String contact;

  /// Auto-attached build/progress context, shown in full before sending. Never
  /// contains reflection content — no gratitude or prayer text, ever.
  final Map<String, String> diagnostics;

  final FeedbackStatus status;

  /// Why the last send attempt didn't land, for the history list. '' when the
  /// report has never failed.
  final String lastError;

  bool get isPending => status == FeedbackStatus.pending;

  FeedbackReport copyWith({FeedbackStatus? status, String? lastError}) =>
      FeedbackReport(
        id: id,
        kind: kind,
        body: body,
        createdAtMs: createdAtMs,
        contact: contact,
        diagnostics: diagnostics,
        status: status ?? this.status,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'body': body,
        'createdAtMs': createdAtMs,
        'contact': contact,
        'diagnostics': diagnostics,
        'status': status.name,
        'lastError': lastError,
      };

  factory FeedbackReport.fromJson(Map<String, dynamic> j) => FeedbackReport(
        id: (j['id'] as String?) ?? '',
        kind: feedbackKindFromName(j['kind'] as String?),
        body: (j['body'] as String?) ?? '',
        createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
        contact: (j['contact'] as String?) ?? '',
        diagnostics: {
          for (final e in ((j['diagnostics'] as Map?) ?? const {}).entries)
            e.key as String: '${e.value}',
        },
        status: j['status'] == FeedbackStatus.sent.name
            ? FeedbackStatus.sent
            : FeedbackStatus.pending,
        lastError: (j['lastError'] as String?) ?? '',
      );
}

/// Why a submission was rejected before it ever reached the device store, or
/// null when the text is fine. Pure so the rules are testable without a widget.
String? validateFeedbackBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'Write something first';
  if (trimmed.length > kFeedbackMaxChars) {
    return 'Keep it under $kFeedbackMaxChars characters';
  }
  return null;
}
