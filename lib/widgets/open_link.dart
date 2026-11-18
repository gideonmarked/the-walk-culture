import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Open [url] in the browser, with a snackbar if nothing can handle it.
Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
