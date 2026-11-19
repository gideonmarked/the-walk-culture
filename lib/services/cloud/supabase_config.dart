/// Backend credentials, injected at build time — never committed.
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
///
/// The anon key is public by design: it identifies the project, it doesn't
/// authorise anything. The wallet and VIP entitlement are protected by the
/// row-level security in supabase/schema.sql, not by hiding this key.
///
/// When [isConfigured] is false the whole cloud layer stays inert and the game
/// runs local-only — which is exactly how it behaves in tests and in any build
/// that hasn't been given credentials.
library;

class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// The **Web** OAuth client ID from Google Cloud Console, used as Google
  /// Sign-In's server client ID so it returns an ID token Supabase can verify:
  ///
  ///   --dart-define=GOOGLE_WEB_CLIENT_ID=1234-abc.apps.googleusercontent.com
  ///
  /// Without it the "Link Google account" option is hidden. See
  /// docs/DEPLOY.md, "Google account linking".
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// The **iOS** OAuth client ID, needed for Google sign-in on iPhone (its
  /// reversed form also goes in ios/Flutter/AppConfig.xcconfig):
  ///
  ///   --dart-define=GOOGLE_IOS_CLIENT_ID=1234-xyz.apps.googleusercontent.com
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
}
