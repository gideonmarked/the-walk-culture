import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback.dart';
import '../../core/notifications.dart' show relativeTime;
import '../../state/feedback_providers.dart';

/// "Send feedback" — report a bug or suggest a feature.
///
/// The submit button promises the report is SAVED, not that it's been
/// delivered: it's written to the device first and sent when there's a
/// connection, so a bug found on a train still reaches us.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _body = TextEditingController();
  final _contact = TextEditingController();
  FeedbackKind _kind = FeedbackKind.bug;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Opening the screen is a good moment to retry anything still queued.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedbackControllerProvider.notifier).flushPending();
    });
  }

  @override
  void dispose() {
    _body.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    final problem = await ref.read(feedbackControllerProvider.notifier).submit(
          kind: _kind,
          body: _body.text,
          contact: _contact.text,
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    _body.clear();
    _contact.clear();
    // The report we just filed is newest-first. Whether it also went out
    // decides the wording: "saved" is the promise we can always keep.
    final stored = ref.read(feedbackControllerProvider);
    final sent = stored.isNotEmpty && stored.first.status == FeedbackStatus.sent;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(sent
            ? 'Thanks — sent. 🙏'
            : "Thanks — saved. It'll send when you're back online."),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(feedbackControllerProvider);
    final diagnostics =
        ref.read(feedbackControllerProvider.notifier).currentDiagnostics;

    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Found a bug, or thought of something the app should do? "
            "Tell us — this is a beta, and it's the fastest way to change it.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          SegmentedButton<FeedbackKind>(
            segments: [
              for (final kind in FeedbackKind.values)
                ButtonSegment(
                  value: kind,
                  icon: Icon(kind.icon),
                  label: Text(kind.shortLabel),
                  tooltip: kind.label,
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _body,
            maxLines: 6,
            minLines: 4,
            maxLength: kFeedbackMaxChars,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: _kind.label,
              alignLabelWithHint: true,
              hintText: _kind == FeedbackKind.bug
                  ? 'What happened, and what were you doing just before?'
                  : 'What would you like to see?',
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _contact,
            maxLength: kFeedbackContactMaxChars,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Email (optional)',
              helperText: 'Only if you want a reply. Leave it blank otherwise.',
            ),
          ),
          const SizedBox(height: 8),

          _DiagnosticsDisclosure(diagnostics: diagnostics),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Sending…' : 'Send'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),

          if (reports.isNotEmpty) ...[
            const Divider(height: 40),
            Text('Your reports',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final report in reports) _ReportTile(report: report),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Exactly what rides along with the report, in full and before sending. The
/// app asks permission before reading a step count; it shouldn't be vaguer
/// about the diagnostics it attaches to a bug report.
class _DiagnosticsDisclosure extends StatelessWidget {
  const _DiagnosticsDisclosure({required this.diagnostics});

  final Map<String, String> diagnostics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('What gets attached'),
        subtitle: Text('${diagnostics.length} details about this build — '
            'no journal or prayer text, ever'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final entry in diagnostics.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(entry.key,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.value,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final FeedbackReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sent = report.status == FeedbackStatus.sent;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(report.kind.icon),
        title: Text(
          report.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${report.kind.shortLabel} · ${relativeTime(report.createdAtMs)}'
          '${sent || report.lastError.isEmpty ? '' : ' · ${report.lastError}'}',
        ),
        trailing: sent
            ? Icon(Icons.cloud_done_outlined, color: scheme.primary, size: 20)
            : Tooltip(
                message: 'Saved on this device — will send when online',
                child: Icon(Icons.schedule,
                    color: scheme.onSurfaceVariant, size: 20),
              ),
      ),
    );
  }
}
