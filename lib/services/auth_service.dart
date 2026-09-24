import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'storage_service.dart';
import 'supabase_config.dart';

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
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

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

  static const List<String> _googleScopes = ['email', 'profile'];

  /// Google sign-in. Web redirects within the same tab via
  /// `signInWithOAuth` (unchanged, already working). Android/iOS use
  /// **native** sign-in instead — `google_sign_in`'s Credential
  /// Manager-backed flow talks to Google Play Services directly on-device
  /// and hands Supabase an ID token via [signInWithIdToken], with no
  /// browser redirect at all. This deliberately replaces an earlier
  /// browser-redirect approach for mobile, which needed a custom
  /// URL-scheme deep link (`io.mathblitz.app://login-callback`) that was
  /// never actually registered in AndroidManifest.xml/Info.plist and so
  /// stranded the player on a blank browser page after signing in.
  ///
  /// Requires [SupabaseConfig.googleWebClientId] to be set to a real Web
  /// OAuth Client ID, and — for Android specifically — that Client ID's
  /// project to also have an **Android** OAuth Client ID registered
  /// (package name + the signing certificate's SHA-1 fingerprint) in
  /// Google Cloud Console, with both Client IDs added to Supabase's
  /// Google provider settings. See ARCHITECTURE.md for the exact values
  /// used for this project.
  ///
  /// iOS additionally needs its own iOS Client ID and a matching
  /// URL-scheme in Info.plist for `initialize()`'s `clientId:` — not
  /// wired here yet, since this project's dev machine (Windows) can't
  /// build or test iOS at all.
  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: SupabaseConfig.googleWebClientId,
    );
    final googleUser = await googleSignIn.authenticate();

    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(
          _googleScopes,
        ) ??
        await googleUser.authorizationClient.authorizeScopes(_googleScopes);
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  /// True once signed in through [signInAsGuest] rather than a real
  /// identity (Google or email) — Supabase's own `is_anonymous` JWT claim,
  /// exposed via `User.isAnonymous`. Nothing in the schema/RLS treats an
  /// anonymous user differently from any other `auth.uid()` — they get a
  /// real `profiles` row, a real leaderboard entry, and can delete their
  /// account (`delete_account_screen.dart`) exactly like everyone else.
  /// The one place this matters: the *external* deletion web page's
  /// "email us if you no longer have the app" fallback doesn't apply to a
  /// guest (no email is ever on file for them) — worth noting if that
  /// page's copy is ever revisited, though it isn't referenced from code.
  static bool get isGuest => currentUser?.isAnonymous ?? false;

  /// Signs in as a guest — a real Supabase account with no email or
  /// password (`auth.signInAnonymously()`), not a fake/local-only mode.
  /// Scores, the leaderboard, and Play progress all work normally; the
  /// account can later be tied to Google sign-in via Supabase's identity
  /// linking (not currently wired into the UI — this just gets a guest
  /// playing immediately, with account creation invisible to them).
  ///
  /// Throws a [StateError] with a founder-friendly message if the
  /// Supabase project doesn't have anonymous sign-ins turned on yet
  /// (Dashboard → Authentication → Sign In / Providers → Anonymous) —
  /// callers should show that message directly rather than Supabase's raw
  /// one, which otherwise reads as a generic, confusing HTTP error.
  static Future<void> signInAsGuest() async {
    try {
      await _client.auth.signInAnonymously();
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('anonymous')) {
        throw StateError(
          'Guest play isn\'t turned on yet for this app. (Founder: enable '
          'it in Supabase Dashboard → Authentication → Sign In / '
          'Providers → Anonymous Sign-Ins.)',
        );
      }
      rethrow;
    }
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Permanently deletes the signed-in player's account and all their
  /// data (profile, persistent score, Daily Challenge history) — the
  /// in-app half of Google Play's required account-deletion flow (the
  /// other half is a public web page reachable outside the app; see
  /// ARCHITECTURE.md). Calls the `delete-own-account` Edge Function,
  /// which resolves and deletes *only* the caller's own identity from
  /// their JWT — this client never sends and the function never trusts
  /// any explicit user id.
  ///
  /// Deliberately lets a failure propagate rather than swallowing it like
  /// most other calls in this file — `functions.invoke` itself throws a
  /// `FunctionException` on any non-2xx response, and the UI must know a
  /// delete request didn't actually go through rather than signing the
  /// player out of an account that still exists. Signs out locally only
  /// after `invoke` returns successfully (i.e. the server has confirmed
  /// deletion), since supabase_flutter's local session has no way to
  /// notice a server-side deletion on its own.
  ///
  /// Also clears every locally-cached stat (`StorageService.clearAll()`)
  /// — a real bug caught on-device: without this, Home kept showing the
  /// deleted account's old marks/streak (read from the phone's own
  /// SharedPreferences cache, untouched by server-side deletion) even
  /// after signing back in fresh, since that fresh sign-in's `PlayerStats`
  /// never gets separately re-fetched from anywhere — Home just trusts
  /// whatever was last saved locally. A brand new account must start
  /// from a genuinely clean local slate, not the previous account's.
  static Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-own-account');
    await signOut();
    await StorageService.clearAll();
  }

  /// Creates this player's `profiles` row if one doesn't already exist.
  /// Called after [signUp] (with the name they typed in the form) and
  /// again from the auth-state listener on every sign-in (covering
  /// Google sign-in, which never goes through [signUp] and so needs its
  /// profile created the first time that user is ever seen).
  static Future<void> ensureProfileExists({
    String? preferredDisplayName,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    final displayName =
        preferredDisplayName ??
        // Set by signUp() at account-creation time — the name the player
        // typed survives even though profile creation itself only
        // happens later, once they've clicked the confirmation link and
        // this runs from the `signedIn` listener in main.dart instead.
        user.userMetadata?['display_name'] as String? ??
        user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.email?.split('@').first ??
        // A guest has no email/Google name to fall back to — a short,
        // stable suffix from their own id keeps every guest's leaderboard
        // entry distinct instead of an indistinguishable sea of "Player".
        (user.isAnonymous
            ? 'Guest${user.id.substring(0, 4).toUpperCase()}'
            : 'Player');

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
        .update({'current_score': score})
        .eq('id', user.id);
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
