import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prayer_requests.dart';
import '../../core/spheres.dart' show kSphereTiers;
import '../../services/cloud/prayer_request_service.dart';
import '../../state/app_providers.dart';
import '../spheres/spheres_screen.dart' show SphereOpenDialog;

/// The shared, anonymous prayer wall. Two deliberate actions:
///   • "Pray for a request" — the randomiser fetches ONE stranger's request when
///     you tap, and praying for it grants a quiet reward (capped daily).
///   • "Send a prayer request" — share your own, anonymously, max 2 / week.
///
/// Everything here needs the backend; offline it shows a friendly stub. The
/// private on-device journal is untouched by this screen.
class PrayerRequestsScreen extends ConsumerStatefulWidget {
  const PrayerRequestsScreen({super.key});

  @override
  ConsumerState<PrayerRequestsScreen> createState() =>
      _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends ConsumerState<PrayerRequestsScreen> {
  SharedPrayerRequest? _current;
  bool _loading = false; // fetching a random request
  bool _praying = false; // recording a prayer + reward
  bool _prayed = false; // prayed for the one on screen
  int? _allowance; // requests left this week (null = unknown/offline)

  PrayerRequestService get _service =>
      ref.read(prayerRequestServiceProvider);

  @override
  void initState() {
    super.initState();
    if (_service.online) _refreshAllowance();
  }

  Future<void> _refreshAllowance() async {
    final n = await _service.allowance();
    if (mounted) setState(() => _allowance = n);
  }

  Future<void> _fetchRandom() async {
    setState(() {
      _loading = true;
      _prayed = false;
    });
    final req = await _service.fetchRandom();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _current = req;
    });
    if (req == null) {
      _snack('No requests to pray for right now — check back soon. 🙏');
    }
  }

  Future<void> _pray() async {
    final req = _current;
    if (req == null || _praying || _prayed) return;
    setState(() => _praying = true);

    final newCount = await _service.pray(req.id);
    final reward =
        await ref.read(playerControllerProvider.notifier).claimRequestPrayerReward();
    if (!mounted) return;

    setState(() {
      _praying = false;
      _prayed = true;
      if (newCount != null) _current = req.withPrayCount(newCount);
    });

    if (reward != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            SphereOpenDialog(tier: kSphereTiers.first, result: reward),
      );
    } else {
      _snack('Prayer counted. 🙏 (daily reward already earned)');
    }
  }

  Future<void> _report() async {
    final req = _current;
    if (req == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report this request?'),
        content: const Text(
            'Report it as inappropriate or unsafe. It’s hidden automatically '
            'once enough people report it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Report')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.report(req.id);
    if (!mounted) return;
    setState(() => _current = null);
    _snack('Reported — thank you for keeping this kind.');
  }

  Future<void> _compose() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ComposeSheet(service: _service),
    );
    if (sent == true) {
      await _refreshAllowance();
      if (mounted) _snack('Sent. Others can now pray for you. 🙏');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerControllerProvider); // rebuild when a reward lands
    final online = _service.online;
    final left = ref.read(playerControllerProvider.notifier).requestPrayerRewardsLeft;

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Requests')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('🙏', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Pray for a stranger, and let strangers pray for you — '
              'anonymously.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),

            if (!online) ...[
              const _OfflineNote(),
              const SizedBox(height: 20),
            ],

            // --- Pray for someone else's request ---------------------------
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pray for a request',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    left > 0
                        ? 'Tap to be given one at random. A reward for each '
                            'prayer — $left left today.'
                        : 'Tap to be given one at random. You’ve earned '
                            'today’s rewards, but every prayer still counts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_current == null)
                    FilledButton.icon(
                      onPressed:
                          (online && !_loading) ? _fetchRandom : null,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.casino_outlined),
                      label: Text(_loading ? 'Finding one…' : 'Give me a request'),
                    )
                  else
                    _RequestCard(
                      request: _current!,
                      prayed: _prayed,
                      praying: _praying,
                      onPray: _pray,
                      onReport: _report,
                      onNext: (online && !_loading) ? _fetchRandom : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Send your own -------------------------------------------
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send a prayer request',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _allowance == null
                        ? 'Shared anonymously. Up to '
                            '$kMaxPrayerRequestsPerWeek per week.'
                        : '$_allowance of $kMaxPrayerRequestsPerWeek left this week.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: (online && (_allowance == null || _allowance! > 0))
                        ? _compose
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(_allowance == 0
                        ? 'No requests left this week'
                        : 'Write a request'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.prayed,
    required this.praying,
    required this.onPray,
    required this.onReport,
    required this.onNext,
  });

  final SharedPrayerRequest request;
  final bool prayed;
  final bool praying;
  final VoidCallback onPray;
  final VoidCallback onReport;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“${request.body}”',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text('${request.prayCount} prayed',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!prayed)
          FilledButton.icon(
            onPressed: praying ? null : onPray,
            icon: praying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.favorite),
            label: Text(praying ? 'Praying…' : 'I prayed 🙏'),
          )
        else
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.refresh),
            label: const Text('Pray for another'),
          ),
        TextButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('Report'),
          style: TextButton.styleFrom(foregroundColor: scheme.outline),
        ),
      ],
    );
  }
}

/// The compose sheet — consent up top, a char-limited field, a Send button.
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.service});
  final PrayerRequestService service;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final err = await widget.service.submit(_controller.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = kPrayerRequestMaxChars - _controller.text.characters.length;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send a prayer request',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(kPrayerRequestConsent,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            maxLength: kPrayerRequestMaxChars,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What can others pray for?',
              border: const OutlineInputBorder(),
              counterText: '$left left',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_sending || _controller.text.trim().isEmpty)
                ? null
                : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(_sending ? 'Sending…' : 'Send anonymously'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Shared prayer requests need a connection. This activates once the '
              'community backend is live.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
