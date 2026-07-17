import 'package:flutter/foundation.dart' show kDebugMode;

/// Whether the in-app developer tools — simulate steps, the health-sync toggle,
/// reset today's steps, and reset all data — are shown.
///
/// True in every debug build, and in a release build ONLY when compiled with
/// `--dart-define=DEV_TOOLS=true`. A public release omits the flag, so the tools
/// compile out entirely (they can mint currency and wipe data — never ship
/// them). Default false = fail safe: forgetting the flag hides the tools, it
/// never exposes them.
///
///   flutter build apk --release --dart-define=DEV_TOOLS=true   # test build
///   flutter build appbundle --release                          # public build
const bool kDevToolsEnabled =
    kDebugMode || bool.fromEnvironment('DEV_TOOLS');
