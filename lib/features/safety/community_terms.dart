import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/links.dart';
import '../../widgets/open_link.dart';

/// Google Play's UGC policy: users must accept the terms of use before they can
/// create content other people see (a username, a group name, a shared prayer
/// request). Asked once; the acceptance is remembered on the device.
const String kCommunityTermsKey = 'twc_community_terms_accepted_v1';

const List<String> kCommunityRules = [
  'Be kind — no harassment, threats or bullying.',
  'No hateful, sexual or violent content.',
  'No personal details: names, phone numbers, addresses or social handles.',
  'No spam, ads or pretending to be someone else.',
];

/// True when the player has accepted (now or earlier); false if they backed out.
Future<bool> ensureCommunityTermsAccepted(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kCommunityTermsKey) ?? false) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    builder: (_) => const _CommunityTermsDialog(),
  );
  if (accepted == true) {
    await prefs.setBool(kCommunityTermsKey, true);
    return true;
  }
  return false;
}

class _CommunityTermsDialog extends StatefulWidget {
  const _CommunityTermsDialog();

  @override
  State<_CommunityTermsDialog> createState() => _CommunityTermsDialogState();
}

class _CommunityTermsDialogState extends State<_CommunityTermsDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Community rules'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Other walkers will see what you post. Please:'),
            const SizedBox(height: 8),
            for (final rule in kCommunityRules)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('•  $rule'),
              ),
            const SizedBox(height: 8),
            const Text('You can report or block anyone who breaks these rules. '
                'We may remove content or accounts that do.'),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => openLink(context, kTermsUrl),
              child: const Text('Read the full terms of use'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: const Text('I agree to the terms of use'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _agreed ? () => Navigator.pop(context, true) : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
