/// This project's Supabase connection details.
///
/// The anon key is *meant* to be public — Supabase's security model relies
/// on Row-Level Security policies (see the SQL run against this project's
/// `profiles`/`daily_test_results` tables) to restrict what it can do, not
/// on keeping this key secret. It is safe to ship inside the compiled app.
abstract final class SupabaseConfig {
  static const String url = 'https://cmdjfvrbhqqkaxhqzfth.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtZGpmdnJiaHFxa2F4aHF6ZnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNDgxMzksImV4cCI6MjEwMzkyNDEzOX0.PLG-wcZmAQfVPmvjtgbAMn4j6CsdVWtrGRPDEDusWNE';

  /// The **Web** OAuth 2.0 Client ID from Google Cloud Console — used as
  /// `serverClientId` for native Google sign-in on Android/iOS (see
  /// `AuthService.signInWithGoogle`) and as the ID-token audience Supabase
  /// validates against. Not a secret — the same public value already
  /// entered into Supabase's Google provider settings. Fill in with your
  /// actual Web Client ID (ends in `.apps.googleusercontent.com`) from
  /// Google Cloud Console > APIs & Services > Credentials.
  static const String googleWebClientId =
      '340162805477-jpekth4lilo3aktvb07ch83lu1hj7qar.apps.googleusercontent.com';
}
