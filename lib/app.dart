import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/root_scaffold.dart';
import 'state/app_providers.dart';

class StepQuestApp extends ConsumerWidget {
  const StepQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'StepQuest',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Steps accrue while the app is backgrounded — sync the moment we return.
    if (state == AppLifecycleState.resumed) {
      ref.read(playerControllerProvider.notifier).syncSteps();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(onboardingProvider);
    return onboarded ? const RootScaffold() : const OnboardingScreen();
  }
}
