import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'services/cloud/cloud_sync_service.dart';
import 'services/consent_service.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op unless the build was given SUPABASE_URL / SUPABASE_ANON_KEY, and it
  // swallows its own errors — a backend outage must never block launch.
  await CloudSyncService.initialize();
  // Notification channel + Android 13 permission. Best-effort; can't block launch.
  unawaited(LocalNotificationService.initialize());
  // GDPR: resolve ad consent, then init the ads SDK. Both swallow their own
  // errors so a hiccup never blocks launch; ad requests are gated on consent.
  unawaited(ConsentService.ensure()
      .then((_) => MobileAds.instance.initialize()));
  runApp(const ProviderScope(child: WalkCultureApp()));
}
