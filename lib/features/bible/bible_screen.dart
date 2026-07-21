import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bible.dart';
import '../../core/spheres.dart' show kSphereTiers;
import '../../state/app_providers.dart';
import '../spheres/spheres_screen.dart' show SphereOpenDialog;

/// Today's verse with a one-minute read timer. The reward unlocks only after the
/// timer runs out, then "Done reading" grants a random shop item (rarity rolled
/// by kBibleRewardOdds), once per day.
class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  late int _secondsLeft;
  Timer? _timer;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = kBibleReadDuration.inSeconds;
    // Only run the countdown if there's a reward to earn today; otherwise the
    // verse is still readable but there's nothing to unlock.
    if (ref.read(playerControllerProvider.notifier).bibleReadyToday) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsLeft <= 1) {
          t.cancel();
          setState(() => _secondsLeft = 0);
        } else {
          setState(() => _secondsLeft--);
        }
      });
    } else {
      _secondsLeft = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _done() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final result =
        await ref.read(playerControllerProvider.notifier).claimBibleReward();
    if (!mounted) return;
    if (result != null) {
      // Reuse the sphere reveal for the "you got X" moment.
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
    final verse = verseForToday();
    ref.watch(playerControllerProvider); // rebuild when the claim lands
    final ready = ref.read(playerControllerProvider.notifier).bibleReadyToday;
    final canFinish = ready && _secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Verse")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(verse.reference,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(
                '“${verse.text}”',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(kBibleVersion, // version attribution
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              if (!ready)
                const Text('Reward already claimed today. Come back tomorrow. 🙏')
              else if (_secondsLeft > 0) ...[
                Text('Take a minute to read and reflect',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                _Countdown(secondsLeft: _secondsLeft),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canFinish && !_claiming ? _done : null,
                  icon: _claiming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(ready
                      ? (canFinish
                          ? 'Done reading — claim reward'
                          : 'Keep reading… ${_secondsLeft}s')
                      : 'Done'),
                ),
              ),
              if (!ready) ...[
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

class _Countdown extends StatelessWidget {
  const _Countdown({required this.secondsLeft});
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final total = kBibleReadDuration.inSeconds;
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (total - secondsLeft) / total,
                strokeWidth: 6,
              ),
              Text('$secondsLeft',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ],
    );
  }
}
