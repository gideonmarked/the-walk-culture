/// Crash / uncaught-error capture.
///
/// This is a DART error recorder, not a native crash reporter: it catches
/// everything the Flutter framework and the Dart runtime raise — exceptions,
/// bad state, null derefs, layout errors, unhandled async failures — which is
/// the overwhelming majority of real bugs. A true native crash (SIGSEGV in a
/// plugin, an OOM kill) tears the process down before Dart runs, and only a
/// native SDK can see those. If you later need that, add one; this covers the
/// ground it can actually cover, with no new dependency and no second vendor.
///
/// Reports ride the same offline outbox as feedback, for the same reason but
/// more so: something just went wrong, so assume the network is unreliable too.
library;

/// Caps on what we keep. A runaway recursion produces a megabyte of stack, and
/// neither prefs nor the server needs it — the top frames are where the bug is.
const int kCrashMessageMaxChars = 500;
const int kCrashStackMaxLines = 40;
const int kCrashStackMaxChars = 4000;

/// Frames used to identify a crash. Enough to separate two different bugs in
/// the same function, few enough that the same bug reached by slightly
/// different paths still collapses into one report.
const int kCrashFingerprintFrames = 3;

enum CrashKind {
  /// Raised by the Flutter framework — build, layout, paint, gesture.
  flutter,

  /// An unhandled error on the platform dispatcher: a failed Future, an async
  /// gap nobody caught.
  async,

  /// Recorded by hand via CrashController.record — e.g. the dev test button.
  manual,
}

CrashKind crashKindFromName(String? name) => CrashKind.values
    .firstWhere((k) => k.name == name, orElse: () => CrashKind.async);

enum CrashStatus { pending, sent }

/// Trim a message to something storable without losing the useful head of it.
String summarizeCrashMessage(Object? error) {
  final text = '$error'.trim();
  if (text.length <= kCrashMessageMaxChars) return text;
  return '${text.substring(0, kCrashMessageMaxChars)}…';
}

/// Keep the top [kCrashStackMaxLines] frames, then hard-cap the characters.
String trimStack(String? stack) {
  if (stack == null) return '';
  final lines = stack
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .take(kCrashStackMaxLines)
      .toList();
  final joined = lines.join('\n');
  if (joined.length <= kCrashStackMaxChars) return joined;
  return '${joined.substring(0, kCrashStackMaxChars)}\n…';
}

/// Strip the parts of a message that vary between otherwise identical crashes,
/// so "Invalid value: 41" and "Invalid value: 42" fingerprint the same. Without
/// this, one loop with a changing index files a hundred separate reports.
String normalizeForFingerprint(String text) => text
    .replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '0x#')
    .replaceAll(RegExp(r'\d+'), '#')
    .trim();

/// A stable key for "this same bug". Built from the first line of the message
/// plus the top few stack frames, both normalized.
String crashFingerprint({required String message, required String stack}) {
  final head = normalizeForFingerprint(message.split('\n').first);
  final frames = stack
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .take(kCrashFingerprintFrames)
      .map(normalizeForFingerprint)
      .join(' | ');
  final key = frames.isEmpty ? head : '$head :: $frames';
  // Bounded — it's a dictionary key and a database column, not prose.
  return key.length <= 300 ? key : key.substring(0, 300);
}

/// One recorded error. Repeats of the same [fingerprint] don't create new
/// reports; they bump [occurrences] and [lastSeenMs] on the existing one, which
/// is what keeps a per-frame layout error from flooding both disk and server.
class CrashReport {
  const CrashReport({
    required this.id,
    required this.fingerprint,
    required this.kind,
    required this.message,
    required this.stack,
    required this.firstSeenMs,
    required this.lastSeenMs,
    this.library = '',
    this.occurrences = 1,
    this.diagnostics = const {},
    this.status = CrashStatus.pending,
  });

  /// Client-generated; the server dedupes retries on it.
  final String id;
  final String fingerprint;
  final CrashKind kind;
  final String message;
  final String stack;

  /// Flutter's own label for where it came from ("widgets library"), when known.
  final String library;

  final int firstSeenMs;
  final int lastSeenMs;
  final int occurrences;

  /// Same build/progress context the feedback form attaches.
  final Map<String, String> diagnostics;

  final CrashStatus status;

  bool get isPending => status == CrashStatus.pending;

  /// Record another sighting of this same bug.
  CrashReport recur({required int atMs}) => copyWith(
        occurrences: occurrences + 1,
        lastSeenMs: atMs,
        // A crash that is still happening hasn't been reported often enough —
        // re-queue it so the updated count goes up with the next flush.
        status: CrashStatus.pending,
      );

  CrashReport copyWith({
    int? occurrences,
    int? lastSeenMs,
    CrashStatus? status,
  }) =>
      CrashReport(
        id: id,
        fingerprint: fingerprint,
        kind: kind,
        message: message,
        stack: stack,
        library: library,
        firstSeenMs: firstSeenMs,
        lastSeenMs: lastSeenMs ?? this.lastSeenMs,
        occurrences: occurrences ?? this.occurrences,
        diagnostics: diagnostics,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fingerprint': fingerprint,
        'kind': kind.name,
        'message': message,
        'stack': stack,
        'library': library,
        'firstSeenMs': firstSeenMs,
        'lastSeenMs': lastSeenMs,
        'occurrences': occurrences,
        'diagnostics': diagnostics,
        'status': status.name,
      };

  factory CrashReport.fromJson(Map<String, dynamic> j) => CrashReport(
        id: (j['id'] as String?) ?? '',
        fingerprint: (j['fingerprint'] as String?) ?? '',
        kind: crashKindFromName(j['kind'] as String?),
        message: (j['message'] as String?) ?? '',
        stack: (j['stack'] as String?) ?? '',
        library: (j['library'] as String?) ?? '',
        firstSeenMs: (j['firstSeenMs'] as num?)?.toInt() ?? 0,
        lastSeenMs: (j['lastSeenMs'] as num?)?.toInt() ?? 0,
        occurrences: (j['occurrences'] as num?)?.toInt() ?? 1,
        diagnostics: {
          for (final e in ((j['diagnostics'] as Map?) ?? const {}).entries)
            e.key as String: '${e.value}',
        },
        status: j['status'] == CrashStatus.sent.name
            ? CrashStatus.sent
            : CrashStatus.pending,
      );
}
