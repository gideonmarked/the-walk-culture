import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/cloud/cloud_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op unless the build was given SUPABASE_URL / SUPABASE_ANON_KEY, and it
  // swallows its own errors — a backend outage must never block launch.
  await CloudSyncService.initialize();
  runApp(const ProviderScope(child: WalkCultureApp()));
}
