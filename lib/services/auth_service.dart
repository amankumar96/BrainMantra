import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth so the rest of the app never touches the
/// `supabase_flutter` client directly. With "Confirm email" turned off in
/// the Supabase project, [signUp] returns an active, logged-in session
/// immediately — no email-confirmation step for the player to go through.
abstract final class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;

  /// Fires on every sign-in, sign-out, and token refresh. `main.dart`'s
  /// auth gate listens to this to decide whether to show the login flow
  /// or go straight to [HomeScreen] — including on a fresh app launch,
  /// since `supabase_flutter` persists sessions locally by default (this
  /// is what makes a signed-up player stay logged in until they actually
  /// sign out or uninstall, with no extra work needed).
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  static Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response =
        await _client.auth.signUp(email: email, password: password);
    if (response.user == null) {
      throw StateError(
        'Sign up did not return a user — check that "Confirm email" is '
        'disabled in the Supabase project (Authentication > Providers > '
        'Email), otherwise no session is issued until the email link is '
        'clicked.',
      );
    }
    await ensureProfileExists(preferredDisplayName: displayName);
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Opens Google's sign-in flow. On web this redirects within the same
  /// tab; on Android/iOS it opens the system browser and redirects back
  /// via [redirectTo] — actually receiving that redirect on mobile needs
  /// the corresponding URL-scheme registered in AndroidManifest.xml /
  /// Info.plist, which is a separate platform-config step not yet done
  /// (this app has only been run on web/desktop so far). Works as-is on
  /// web with no further setup.
  static Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.mathblitz.app://login-callback',
    );
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Creates this player's `profiles` row if one doesn't already exist.
  /// Called after [signUp] (with the name they typed in the form) and
  /// again from the auth-state listener on every sign-in (covering
  /// Google sign-in, which never goes through [signUp] and so needs its
  /// profile created the first time that user is ever seen).
  static Future<void> ensureProfileExists({String? preferredDisplayName}) async {
    final user = currentUser;
    if (user == null) return;

    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    final displayName = preferredDisplayName ??
        user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.email?.split('@').first ??
        'Player';

    try {
      await _client.from('profiles').insert({
        'id': user.id,
        'display_name': displayName,
      });
    } on PostgrestException catch (e) {
      // A duplicate-key error here means another call already created
      // the row (a harmless race, not a real failure) — anything else
      // should still surface.
      if (e.code != '23505') rethrow;
    }
  }
}
