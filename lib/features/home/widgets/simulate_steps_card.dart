import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../state/app_providers.dart';

/// Prototype-only: credit an arbitrary number of steps without walking.
class SimulateStepsCard extends ConsumerStatefulWidget {
  const SimulateStepsCard({super.key});

  @override
  ConsumerState<SimulateStepsCard> createState() => _SimulateStepsCardState();
}

class _SimulateStepsCardState extends ConsumerState<SimulateStepsCard> {
  static const _presets = [100, 500, 1000, 5000];

  /// Prefills the custom dialog so repeat runs of the same amount are one edit.
  int _lastCustom = 2500;

  Future<void> _add(int steps) async {
    await ref.read(playerControllerProvider.notifier).addSimulatedSteps(steps);
    if (!mounted) return;
    final fmt = NumberFormat.decimalPattern();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added ${fmt.format(steps)} steps'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _promptCustom() async {
    final steps = await showDialog<int>(
      context: context,
      builder: (_) => _CustomStepsDialog(initial: _lastCustom),
    );
    if (steps == null) return;
    setState(() => _lastCustom = steps);
    await _add(steps);
  }

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simulate steps',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        'Credit steps without walking',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    label: Text('+${compact.format(preset)}'),
                    onPressed: () => _add(preset),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Custom'),
                  onPressed: _promptCustom,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomStepsDialog extends StatefulWidget {
  const _CustomStepsDialog({required this.initial});

  final int initial;

  @override
  State<_CustomStepsDialog> createState() => _CustomStepsDialogState();
}

class _CustomStepsDialogState extends State<_CustomStepsDialog> {
  late final _controller =
      TextEditingController(text: widget.initial.toString());
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  String? _validate(String? value) {
    final steps = int.tryParse(value ?? '');
    if (steps == null || steps <= 0) return 'Enter a number above 0';
    if (steps > 1000000) return 'Keep it under 1,000,000';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom step amount'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Steps',
            suffixText: 'steps',
          ),
          validator: _validate,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
