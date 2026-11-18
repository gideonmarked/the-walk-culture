import 'package:flutter/material.dart';

/// Reasons a player can pick when reporting someone or something. Stored as the
/// report's `reason` for review (see user_report in supabase/safety.sql).
const List<String> kReportReasons = [
  'Harassment or bullying',
  'Hateful or offensive',
  'Sexual content',
  'Spam or scam',
  'Shares personal information',
  'Something else',
];

/// Ask why [subject] is being reported. Null if the player cancels.
Future<String?> pickReportReason(BuildContext context, String subject) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Report $subject'),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('What’s wrong? We review every report.'),
        ),
        for (final reason in kReportReasons)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, reason),
            child: Text(reason),
          ),
      ],
    ),
  );
}

/// Confirm blocking. [effect] says what blocking does in this context.
Future<bool> confirmBlock(BuildContext context,
    {required String title, required String effect}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(effect),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block')),
      ],
    ),
  );
  return ok ?? false;
}
