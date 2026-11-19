import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/cloud/google_link_service.dart';
import '../../state/app_providers.dart';
import '../../state/local_reset.dart';

/// Settings row for the optional Google account: link it (keeps this phone's
/// progress), switch to it (on a new phone), or sign out. Hidden on builds
/// without Google sign-in configured.
class GoogleAccountTile extends ConsumerStatefulWidget {
  const GoogleAccountTile({super.key});

  @override
  ConsumerState<GoogleAccountTile> createState() => _GoogleAccountTileState();
}

class _GoogleAccountTileState extends ConsumerState<GoogleAccountTile> {
  bool _busy = false;

  GoogleLinkService get _service => ref.read(googleLinkServiceProvider);

  void _toast(ScaffoldMessengerState messenger, String m) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _link() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await _service.link();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result.outcome) {
      case LinkOutcome.linked:
        _toast(messenger,
            'Linked to ${_service.linkedEmail} — your progress is safe');
      case LinkOutcome.cancelled:
        break;
      case LinkOutcome.failed:
        _toast(messenger, result.message ?? 'Could not link your account');
      case LinkOutcome.belongsToAnotherAccount:
        await _offerSwitch(result.idToken!);
    }
  }

  Future<void> _offerSwitch(String idToken) async {
    final pebbles = NumberFormat.decimalPattern()
        .format(ref.read(playerControllerProvider).lifetimeSteps);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('This Google account already has progress'),
        content: Text(
            'Switch to it to load that progress on this phone.\n\n'
            'The progress on this phone ($pebbles lifetime Pebbles) will be '
            'deleted and replaced. To keep it instead, cancel and link a '
            'different Google account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch account')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAndRebuild(() => _service.switchToExisting(idToken),
        done: 'Signed in — loading your progress');
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your progress stays saved in your Google account — sign in again '
            'any time to get it back. This phone will start fresh.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAndRebuild(_service.signOut, done: 'Signed out');
  }

  /// Run an account change, then reload the app's state from storage.
  Future<void> _runAndRebuild(Future<String?> Function() action,
      {required String done}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    ref.read(playerControllerProvider.notifier).prepareForAccountChange();
    final err = await action();
    if (err != null) {
      // Nothing changed: rebuild so syncing and backups resume.
      rebuildLocalState(ref);
      if (mounted) setState(() => _busy = false);
      _toast(messenger, err);
      return;
    }
    navigator.popUntil((route) => route.isFirst);
    rebuildLocalState(ref);
    _toast(messenger, done);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(googleLinkServiceProvider);
    if (!service.available) return const SizedBox.shrink();
    final email = service.linkedEmail;
    final busy = _busy
        ? const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : null;

    if (email == null) {
      return ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: const Text('Link Google account'),
        subtitle: const Text(
            'Keep your progress safe and bring it to a new phone. Already '
            'linked on another phone? Tap here to sign in.'),
        isThreeLine: true,
        trailing: busy ?? const Icon(Icons.chevron_right),
        onTap: _busy ? null : _link,
      );
    }
    return ListTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: const Text('Signed in with Google'),
      subtitle: Text('$email · progress backed up'),
      trailing: busy ??
          TextButton(onPressed: _signOut, child: const Text('Sign out')),
    );
  }
}
