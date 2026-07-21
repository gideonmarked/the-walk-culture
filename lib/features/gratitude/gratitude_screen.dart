import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gratitude.dart';
import '../../core/spheres.dart' show kSphereTiers;
import '../../core/streaks.dart' show dayKey;
import '../../state/app_providers.dart';
import '../../state/gratitude_journal.dart';
import '../spheres/spheres_screen.dart' show SphereOpenDialog;

/// Name a few things you're thankful for. Entries are saved ON-DEVICE only (see
/// GratitudeJournal). The reward is always a single common item — the practice
/// is the point.
class GratitudeScreen extends ConsumerStatefulWidget {
  const GratitudeScreen({super.key});

  @override
  ConsumerState<GratitudeScreen> createState() => _GratitudeScreenState();
}

class _GratitudeScreenState extends ConsumerState<GratitudeScreen> {
  final _controllers =
      List.generate(kGratitudeCount, (_) => TextEditingController());
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allFilled =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _done() async {
    if (_saving || !_allFilled) return;
    setState(() => _saving = true);
    final today = dayKey(DateTime.now());
    // Save the reflection locally (never uploaded).
    await ref
        .read(gratitudeJournalProvider.notifier)
        .addEntry(today, _controllers.map((c) => c.text).toList());
    // Grant the (common) reward once per day.
    final result =
        await ref.read(playerControllerProvider.notifier).claimGratitudeReward();
    if (!mounted) return;
    if (result != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SphereOpenDialog(tier: kSphereTiers.first, result: result),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Reward already claimed today.')),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerControllerProvider);
    final ready = ref.read(playerControllerProvider.notifier).gratitudeReadyToday;
    final entries = ref.watch(gratitudeJournalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gratitude')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: Text('🙏💛', style: TextStyle(fontSize: 48))),
            const SizedBox(height: 12),
            Text('What are you thankful for today?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Stays on your device — never uploaded.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            for (var i = 0; i < kGratitudeCount; i++) ...[
              TextField(
                controller: _controllers[i],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  prefixText: '${i + 1}.  ',
                  hintText: kGratitudeHints[i % kGratitudeHints.length],
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _allFilled && !_saving ? _done : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(ready ? 'Done — save & claim' : 'Done — save'),
            ),
            if (entries.isNotEmpty) ...[
              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Past entries',
                      style: Theme.of(context).textTheme.titleSmall),
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear journal?'),
                          content: const Text(
                              'This permanently deletes all your entries from this device.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Clear')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref.read(gratitudeJournalProvider.notifier).clear();
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              for (final e in entries.take(14))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.date,
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        for (final item in e.items) Text('• $item'),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
