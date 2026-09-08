import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/crash_providers.dart';
import 'crash.dart';

/// Installs the global Dart error handlers.
///
/// Both hooks are ADDITIVE: they record, then hand the error on to the machinery
/// that would have handled it anyway. So the red screen still appears, the
/// console still prints, and nothing gets quieter just because we started
/// listening. A crash reporter that hides errors from the developer is a net
/// loss.
class CrashReporter {
  const CrashReporter._();

  static ProviderContainer? _container;

  /// Wire up [FlutterError.onError] and [PlatformDispatcher.instance.onError].
  /// Call once from `main()`, after the container exists. Idempotent.
  static void install(ProviderContainer container) {
    _container = container;

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _record(
        details.exception,
        details.stack,
        kind: CrashKind.flutter,
        library: details.library ?? '',
      );
      // Preserve whatever was there — by default presentError, which is what
      // paints the red screen and logs to the console.
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _record(error, stack, kind: CrashKind.async);
      // false = "not fully handled": Flutter still reports it the default way,
      // so this only ADDS recording rather than swallowing the error.
      return false;
    };
  }

  /// Record something by hand — a caught-but-notable failure, or the dev test
  /// button. Safe to call before [install].
  static void report(Object error, [StackTrace? stack]) =>
      _record(error, stack, kind: CrashKind.manual);

  static void _record(
    Object error,
    StackTrace? stack, {
    required CrashKind kind,
    String library = '',
  }) {
    final container = _container;
    if (container == null) return;
    try {
      // Fire and forget: an error handler must not await, and record() already
      // swallows its own failures.
      container.read(crashControllerProvider.notifier).record(
            error: error,
            stack: stack,
            kind: kind,
            library: library,
          );
    } catch (e) {
      debugPrint('could not record crash (ignored): $e');
    }
  }

  /// Test seam — forget the container so a test can install a fresh one.
  @visibleForTesting
  static void reset() => _container = null;
}
