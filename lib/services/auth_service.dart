import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth so the rest of the app never touches the
/// `supabase_flutter` client directly. "Confirm email" is turned ON for
/// this project, so an email/password [signUp] does not return an active
/// session until the player clicks the link in the confirmation email —
/// see [SignUpResult]. Google sign-in ([signInWithGoogle]) never goes
/// through email confirmation and is the flow the UI steers players
/// toward first for that reason.
/// What happened as a result of an email/password [AuthService.signUp]
/// call. [confirmationEmailSent] means the account exists but is not
/// usable yet — the player must click the link Supabase just emailed
/// them before they can log in.
enum SignUpResult { signedIn, confirmationEmailSent }

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

  static Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      // Carried in user metadata so the name typed here survives the gap
      // between now and whenever the confirmation link gets clicked —
      // ensureProfileExists picks it up from here as a fallback below.
      data: {'display_name': displayName},
    );
    if (response.session != null) {
      // No confirmation pending (e.g. this player already confirmed a
      // prior sign-up attempt with the same address) — log straight in.
      await ensureProfileExists(preferredDisplayName: displayName);
      return SignUpResult.signedIn;
    }
    return SignUpResult.confirmationEmailSent;
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
        // Set by signUp() at account-creation time — the name the player
        // typed survives even though profile creation itself only
        // happens later, once they've clicked the confirmation link and
        // this runs from the `signedIn` listener in main.dart instead.
        user.userMetadata?['display_name'] as String? ??
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

  /// The player's persisted Play-mode score — this is what makes "Play"
  /// resume from exactly where they left off, since the score lives on
  /// their account rather than resetting each session. Returns 0 if
  /// signed out, the profile row somehow doesn't have one yet, or the
  /// request fails (e.g. offline) — a fresh-player default is always a
  /// safe fallback here, and Play should never be unreachable just
  /// because this one read failed.
  static Future<int> fetchCurrentScore() async {
    try {
      final user = currentUser;
      if (user == null) return 0;
      final row = await _client
          .from('profiles')
          .select('current_score')
          .eq('id', user.id)
          .maybeSingle();
      return (row?['current_score'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Persists the new running Play-mode total after a session ends.
  static Future<void> updateCurrentScore(int score) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'current_score': score}).eq('id', user.id);
  }

  /// Marks this player as active right now — called at the end of every
  /// session (Play or Daily Challenge). This is the timestamp the 30-day
  /// inactive-account deletion job checks.
  static Future<void> touchLastActive() async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'last_active_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', user.id);
  }
}
