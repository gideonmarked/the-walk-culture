import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/cloud/account_service.dart';
import '../../state/app_providers.dart';
import '../../state/crash_providers.dart';
import '../../state/feedback_providers.dart';
import '../../state/gratitude_journal.dart';
import '../../state/notifications.dart';
import '../../state/premium_providers.dart';

/// What the confirmation dialog tells the player will be deleted. Kept in step
/// with docs/delete-account.html and delete_my_account() in supabase/safety.sql.
const String kDeleteAccountWarning =
    'This permanently deletes your account and everything in it: your progress, '
    'Pebbles, items, streaks, friends, groups you own, shared prayer requests, '
    'and everything the app stored on this phone, including your journal.\n\n'
    'This cannot be undone. Deleting your account does not cancel a VIP '
    'subscription — cancel that in Google Play.';

/// Ask, then delete the account and reset the app to a fresh install.
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(kDeleteAccountWarning),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete forever'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  final error = await ref.read(accountServiceProvider).deleteAccount();
  navigator.pop(); // the progress dialog

  if (error != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
    return;
  }

  // Back to the root, then rebuild every piece of local state from the now
  // empty storage — the app behaves like a fresh install (onboarding first).
  navigator.popUntil((route) => route.isFirst);
  for (final p in <ProviderOrFamily>[
    playerControllerProvider,
    premiumControllerProvider,
    gratitudeJournalProvider,
    notificationsProvider,
    feedbackControllerProvider,
    crashControllerProvider,
    healthSyncProvider,
    onboardingProvider,
  ]) {
    ref.invalidate(p);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
        const SnackBar(content: Text('Your account and data were deleted')));
}
