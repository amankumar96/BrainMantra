// Called by a signed-in player (from AuthService.deleteAccount() in the
// Flutter app) to permanently delete their own account and data — the
// in-app half of Google Play's required account-deletion flow (the other
// half is a public web page reachable outside the app; see
// ARCHITECTURE.md for both).
//
// Security note: this function NEVER trusts a client-supplied user id.
// The only identity it acts on is whatever the caller's own JWT (sent as
// the standard Authorization header by supabase_flutter's
// functions.invoke) actually resolves to — so a player can only ever
// delete themselves, never anyone else, no matter what they might send.
//
// Uses the service-role key — auto-injected by the Supabase platform for
// every deployed Edge Function as SUPABASE_SERVICE_ROLE_KEY, never
// hardcoded here and never shipped in the Flutter app — for two things:
// validating the caller's JWT (adminClient.auth.getUser(jwt) works for
// any valid token, not just the service role's own) and the actual
// Auth Admin API delete call, which properly cleans up Supabase's own
// auth-internal bookkeeping (a raw SQL DELETE would not).
// profiles/daily_test_results rows are removed automatically via the
// same `on delete cascade` foreign keys delete-inactive-users relies on.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Missing or malformed Authorization header' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }
  const jwt = authHeader.slice('Bearer '.length);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  // Resolves the caller's own identity from their token — this is the
  // one and only source of "who" gets deleted.
  const { data: userData, error: userError } =
    await adminClient.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return new Response(
      JSON.stringify({ error: 'Invalid or expired session' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const { error: deleteError } =
    await adminClient.auth.admin.deleteUser(userData.user.id);
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
