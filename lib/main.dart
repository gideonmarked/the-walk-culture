import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'services/cloud/cloud_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op unless the build was given SUPABASE_URL / SUPABASE_ANON_KEY, and it
  // swallows its own errors — a backend outage must never block launch.
  await CloudSyncService.initialize();
  // Init the ads SDK; failure must not block launch (e.g. no Play Services).
  unawaited(MobileAds.instance.initialize());
  runApp(const ProviderScope(child: WalkCultureApp()));
}
