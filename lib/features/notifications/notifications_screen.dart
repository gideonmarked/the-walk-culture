import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_flags.dart';
import '../../core/notifications.dart';
import '../../state/notifications.dart';

/// The in-app inbox: system milestones, rewards, and prayer activity, newest
/// first. Opening it marks everything read (clears the app-bar badge).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (kDevToolsEnabled)
            IconButton(
              tooltip: 'Send a test notification (dev)',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => notifier.add(
                kind: NotifKind.system,
                title: 'Test notification',
                body: 'This is what a tray + inbox alert looks like. 🔔',
                id: 'test-${DateTime.now().millisecondsSinceEpoch}',
              ),
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: notifier.clear,
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => notifier.remove(n.id),
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer,
                      child: Icon(n.kind.icon,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer),
                    ),
                    title: Text(n.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(n.body),
                    trailing: Text(relativeTime(n.createdAtMs),
                        style: Theme.of(context).textTheme.labelSmall),
                    isThreeLine: n.body.length > 40,
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text("You're all caught up",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Milestones, rewards, and when someone prays for your request will '
              'show up here.',
              textAlign: TextAlign.center,
              style: subtle,
            ),
          ],
        ),
      ),
    );
  }
}
