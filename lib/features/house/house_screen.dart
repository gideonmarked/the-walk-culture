import 'package:flutter/material.dart';

/// Home/room customisation (a tab inside Profile) — not built yet. Placeholder
/// until home customisation ships (character customisation is prioritised).
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏗️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('Home customization',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Under construction — coming soon!',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
