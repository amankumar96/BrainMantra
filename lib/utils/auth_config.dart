/// Whether the email/password sign-up and log-in forms are shown at all.
///
/// Set to `false` for launch: Google Sign-In is the only path, which needs
/// no email-sending infrastructure (Supabase's default email sender is
/// rate-limited to only a handful of emails/hour — fine for dev testing,
/// not for real users — and a paid/custom SMTP provider like Resend is the
/// real fix, deliberately deferred past v1). The email/password screens
/// and [AuthService]'s [AuthService.signUp]/[AuthService.signIn] code are
/// left fully in place, not deleted — flip this back to `true` once a
/// custom SMTP sender is configured in the Supabase dashboard (see
/// `Documents/SUPABASE_SECURITY.md`) to bring email sign-up back.
const bool kEmailPasswordSignInEnabled = false;
