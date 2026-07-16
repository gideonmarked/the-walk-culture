import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_providers.dart';

/// Consent-first onboarding (doc §3.6): explain the value BEFORE firing the OS
/// permission prompt, and let the user proceed even if they decline.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    // Explicitly request health permission (time-bounded so it can't hang),
    // then mark onboarding complete so syncing/pedometer can start.
    await ref.read(healthServiceProvider).requestPermission();
    await ref.read(onboardingProvider.notifier).complete();
    await ref.read(playerControllerProvider.notifier).syncSteps();
  }

  Future<void> _skip() async {
    await ref.read(onboardingProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: Text('👣', style: TextStyle(fontSize: 72))),
              const SizedBox(height: 24),
              Text('StepQuest',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Turn your real-world steps into currency, then spend it on your '
                'character and your home.\n\nConnect your health data so we can '
                'count your steps. We never sell it or use it for ads.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Connect health data'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
