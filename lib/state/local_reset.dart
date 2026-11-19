import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'crash_providers.dart';
import 'feedback_providers.dart';
import 'gratitude_journal.dart';
import 'notifications.dart';
import 'premium_providers.dart';

/// Rebuild every piece of local state from storage, after the storage itself
/// was cleared or the signed-in account changed (account deletion, switching
/// to a Google account, signing out). Each controller reloads from
/// SharedPreferences; the player controller also pulls the cloud save when
/// there is no local one, which is how a switched-to account's progress
/// arrives.
void rebuildLocalState(WidgetRef ref) {
  for (final p in <ProviderOrFamily>[
    playerControllerProvider,
    premiumControllerProvider,
    gratitudeJournalProvider,
    notificationsProvider,
    feedbackControllerProvider,
    crashControllerProvider,
    healthSyncProvider,
    // Last: if onboarding resets, the screen holding [ref] may be torn down.
    onboardingProvider,
  ]) {
    ref.invalidate(p);
  }
}
