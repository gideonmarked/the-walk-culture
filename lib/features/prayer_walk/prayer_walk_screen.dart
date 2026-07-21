import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/prayer.dart';
import '../../core/spheres.dart' show kSphereTiers;
import '../../state/app_providers.dart';
import '../spheres/spheres_screen.dart' show SphereOpenDialog;

/// Pray while you walk — your real steps are the timer. A new prompt surfaces
/// every [kPrayerWalkPromptInterval] steps; at [kPrayerWalkTargetSteps] the walk
/// is complete and "Amen" grants the (quiet) reward, once per day.
class PrayerWalkScreen extends ConsumerStatefulWidget {
  const PrayerWalkScreen({super.key});

  @override
  ConsumerState<PrayerWalkScreen> createState() => _PrayerWalkScreenState();
}

class _PrayerWalkScreenState extends ConsumerState<PrayerWalkScreen> {
  int? _startSteps; // effective step count when the walk began
  bool _claiming = false;

  /// The live counter if the pedometer is emitting, else today's synced total —
  /// the same source Home shows, so both real walking and the dev simulator
  /// drive progress.
  int _effectiveSteps() =>
      ref.read(liveStepsProvider) ??
      ref.read(playerControllerProvider).todaySteps;

  void _begin() => setState(() => _startSteps = _effectiveSteps());

  Future<void> _amen() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final result =
        await ref.read(playerControllerProvider.notifier).claimPrayerWalkReward();
    if (!mounted) return;
    if (result != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SphereOpenDialog(tier: kSphereTiers.first, result: result),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild as steps tick in (live counter, and the synced total).
    ref.watch(liveStepsProvider);
    ref.watch(playerControllerProvider.select((p) => p.todaySteps));
    final ready = ref.read(playerControllerProvider.notifier).prayerWalkReadyToday;

    final walked =
        _startSteps == null ? 0 : (_effectiveSteps() - _startSteps!).clamp(0, kPrayerWalkTargetSteps);
    final progress = walked / kPrayerWalkTargetSteps;
    final done = _startSteps != null && walked >= kPrayerWalkTargetSteps;
    final promptIndex =
        (walked ~/ kPrayerWalkPromptInterval).clamp(0, kPrayerWalkPrompts.length - 1);
    final fmt = NumberFormat.decimalPattern();

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Walk')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _startSteps == null
              ? _Intro(ready: ready, onBegin: _begin)
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text('🚶🙏', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 24),
                    // The practice is centre stage; the counter sits under it.
                    Expanded(
                      child: Center(
                        child: Text(
                          kPrayerWalkPrompts[promptIndex],
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(height: 1.4),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: progress, minHeight: 10),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      done
                          ? 'Walk complete 🙏'
                          : '${fmt.format(walked)} / ${fmt.format(kPrayerWalkTargetSteps)} steps in prayer',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: done && ready && !_claiming ? _amen : null,
                        icon: _claiming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.favorite),
                        label: Text(!ready
                            ? 'Amen'
                            : (done ? 'Amen — claim reward' : 'Keep walking…')),
                      ),
                    ),
                    if (done && !ready) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.ready, required this.onBegin});
  final bool ready;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Column(
      children: [
        const Spacer(),
        const Text('🚶🙏', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 20),
        Text('Walk and pray',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Take a ${fmt.format(kPrayerWalkTargetSteps)}-step walk in prayer. A '
          'new prompt appears as you go — no need to look at your phone. Just '
          'walk, and pray.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Spacer(),
        if (!ready)
          const Text("Today's reward is already claimed — you can still walk. 🙏",
              textAlign: TextAlign.center),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onBegin,
            icon: const Icon(Icons.directions_walk),
            label: const Text('Begin the walk'),
          ),
        ),
      ],
    );
  }
}
