/// Build identity — for anything that has to answer "which version is this?".
///
/// Today that's the feedback form: a bug report is close to useless if you
/// can't tell which build it was filed against.
library;

/// Must match `version:` in pubspec.yaml.
///
/// Reading pubspec at runtime needs `package_info_plus`, and a whole dependency
/// for one string isn't worth it — so this is hand-kept, and a test parses
/// pubspec.yaml and fails if the two ever drift (see test/feedback_test.dart).
const String kAppVersion = '0.1.0+1';
