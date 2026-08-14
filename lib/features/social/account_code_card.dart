import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/cloud/social_service.dart';
import '../../state/app_providers.dart';

/// The player's username + shareable account code, with copy/edit affordances.
/// The code is minted locally on first run, so it's always present — even
/// signed-out/offline, which is the whole point: you can hand it to a friend
/// before any backend exists. Shared by the Profile and Friends & Groups.
class AccountCodeCard extends StatelessWidget {
  const AccountCodeCard({
    super.key,
    required this.username,
    required this.accountCode,
    required this.onCopy,
    required this.onEditName,
  });

  final String username;
  final String accountCode;
  final VoidCallback onCopy;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username.isEmpty ? 'No username yet' : username,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onEditName,
                        icon: const Icon(Icons.edit, size: 18),
                      ),
                    ],
                  ),
                  Text('Your code',
                      style: Theme.of(context).textTheme.bodySmall),
                  SelectableText(
                    accountCode.isEmpty ? '…' : accountCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
                onPressed: onCopy, icon: const Icon(Icons.copy)),
          ],
        ),
      ),
    );
  }
}

/// Prompt for a username, persist it, and publish it to the backend (if live).
/// Shared so the Profile and the Friends & Groups screen behave identically.
Future<void> showUsernameEditor(BuildContext context, WidgetRef ref) async {
  final current = ref.read(playerControllerProvider).username;
  final ctrl = TextEditingController(text: current);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choose a username'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 20,
        decoration: const InputDecoration(hintText: 'e.g. StrollKing'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save')),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  await ref.read(playerControllerProvider.notifier).setUsername(name);
  final p = ref.read(playerControllerProvider);
  await ref
      .read(socialServiceProvider)
      .upsertProfile(username: p.username, accountCode: p.accountCode);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Username set to $name')));
  }
}
