import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../services/cloud/account_link_service.dart';
import '../../state/app_providers.dart';
import '../../state/local_reset.dart';

/// Settings section for the optional linked login: link Google or Apple
/// (keeps this phone's progress), switch to an existing account (on a new
/// phone), or sign out. Hidden on builds with no sign-in configured.
class AccountLinkTile extends ConsumerStatefulWidget {
  const AccountLinkTile({super.key});

  @override
  ConsumerState<AccountLinkTile> createState() => _AccountLinkTileState();
}

class _AccountLinkTileState extends ConsumerState<AccountLinkTile> {
  bool _busy = false;

  AccountLinkService get _service => ref.read(accountLinkServiceProvider);

  void _toast(ScaffoldMessengerState messenger, String m) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _link(SignInProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await _service.link(provider);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result.outcome) {
      case LinkOutcome.linked:
        _toast(messenger,
            'Linked to ${_service.linkedLabel} — your progress is safe');
      case LinkOutcome.cancelled:
        break;
      case LinkOutcome.failed:
        _toast(messenger, result.message ?? 'Could not link your account');
      case LinkOutcome.belongsToAnotherAccount:
        await _offerSwitch(result.credential!);
    }
  }

  Future<void> _offerSwitch(ProviderCredential cred) async {
    final pebbles = NumberFormat.decimalPattern()
        .format(ref.read(playerControllerProvider).lifetimeSteps);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('This ${cred.provider.label} account already has progress'),
        content: Text(
            'Switch to it to load that progress on this phone.\n\n'
            'The progress on this phone ($pebbles lifetime Pebbles) will be '
            'deleted and replaced. To keep it instead, cancel and link a '
            'different account.'),
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
    await _runAndRebuild(() => _service.switchToExisting(cred),
        done: 'Signed in — loading your progress');
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your progress stays saved in your account — sign in again any '
            'time to get it back. This phone will start fresh.'),
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

  Widget _providerButton(SignInProvider p) {
    final onPressed = _busy ? null : () => _link(p);
    switch (p) {
      case SignInProvider.apple:
        return SignInWithAppleButton(
          text: 'Continue with Apple',
          height: 44,
          style: Theme.of(context).brightness == Brightness.dark
              ? SignInWithAppleButtonStyle.white
              : SignInWithAppleButtonStyle.black,
          onPressed: onPressed ?? () {},
        );
      case SignInProvider.google:
        return SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Text('G',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            label: const Text('Continue with Google'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(accountLinkServiceProvider);
    final providers = service.availableProviders;
    if (providers.isEmpty) return const SizedBox.shrink();
    final label = service.linkedLabel;

    if (label != null) {
      return ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Signed in'),
        subtitle: Text('$label · progress backed up'),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: _signOut, child: const Text('Sign out')),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Back up your progress',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Link an account to keep your progress safe and bring it to a new '
            'phone. Already linked on another phone? Sign in the same way.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final p in providers) ...[
            _providerButton(p),
            const SizedBox(height: 8),
          ],
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
