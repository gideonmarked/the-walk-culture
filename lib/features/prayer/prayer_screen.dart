import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prayer.dart';
import '../../core/spheres.dart' show kSphereTiers;
import '../../state/app_providers.dart';
import '../spheres/spheres_screen.dart' show SphereOpenDialog;

/// "Pray for someone" — an optional name to hold in mind, a two-minute timer,
/// then "Amen" grants a random shop item (rarity from kPrayerRewardOdds), once
/// per day.
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  final _nameController = TextEditingController();
  late int _secondsLeft;
  Timer? _timer;
  bool _started = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = kPrayerDuration.inSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _amen() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final result =
        await ref.read(playerControllerProvider.notifier).claimPrayerReward();
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

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    ref.watch(playerControllerProvider); // rebuild when the claim lands
    final ready = ref.read(playerControllerProvider.notifier).prayerReadyToday;
    final canFinish = ready && _started && _secondsLeft == 0;
    final who = _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Pray for Someone')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text('🙏', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              if (!_started) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Who are you praying for? (optional)',
                    hintText: 'A name, or leave blank',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Text(prayerPromptForToday(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                if (!ready)
                  const Text(
                      'Reward already claimed today. You can still pray. 🙏',
                      textAlign: TextAlign.center),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.self_improvement),
                    label: Text(ready ? 'Begin — 2 minutes' : 'Begin praying'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  who.isEmpty ? 'Praying…' : 'Praying for $who',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(prayerPromptForToday(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (kPrayerDuration.inSeconds - _secondsLeft) /
                            kPrayerDuration.inSeconds,
                        strokeWidth: 8,
                      ),
                      Text(_fmt(_secondsLeft),
                          style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canFinish && !_claiming ? _amen : null,
                    icon: _claiming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.favorite),
                    label: Text(!ready
                        ? 'Amen'
                        : (canFinish
                            ? 'Amen — claim reward'
                            : 'Keep praying… ${_fmt(_secondsLeft)}')),
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
            ],
          ),
        ),
      ),
    );
  }
}
