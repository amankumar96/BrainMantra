// Scheduled daily (see the cron SQL you'll run after deploying this) to
// delete any account that hasn't been active in 30+ days.
//
// Uses the service-role key — auto-injected by the Supabase platform for
// every deployed Edge Function as the SUPABASE_SERVICE_ROLE_KEY
// environment variable, never hardcoded here and never shipped in the
// Flutter app — to call the Auth Admin API. That's what properly cleans
// up Supabase's own auth-internal bookkeeping (sessions, identities,
// refresh tokens); a raw SQL `DELETE FROM auth.users` would not.
// `profiles`/`daily_test_results` rows are removed automatically by the
// `on delete cascade` foreign keys added in the same migration that adds
// the `last_active_at` column this function reads.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const INACTIVITY_DAYS = 30;
// Safety cap: at most this many accounts are deleted per run. If the job
// ever misfires (e.g. a bad `last_active_at` migration), the damage is
// bounded; the next daily run simply picks up the rest.
const MAX_DELETES_PER_RUN = 200;

// SECURITY: this function used to accept ANY caller holding the app's
// public anon key (which ships inside every APK). It now also requires a
// private shared secret in the `x-cron-secret` header - only the daily
// pg_cron job knows it. If CRON_SECRET isn't configured, the function
// refuses to run at all (fail closed) rather than silently staying open.
// See Documents/SUPABASE_SECURITY.md for how to set it and update the job.
function constantTimeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  const expectedSecret = Deno.env.get('CRON_SECRET');
  if (!expectedSecret) {
    return new Response(
      JSON.stringify({ error: 'Server not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
  const providedSecret = req.headers.get('x-cron-secret') ?? '';
  if (!constantTimeEqual(providedSecret, expectedSecret)) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const cutoff = new Date();
  cutoff.setUTCDate(cutoff.getUTCDate() - INACTIVITY_DAYS);

  // Find every profile that hasn't touched last_active_at since the
  // cutoff — this is exactly the set of accounts the product rule says
  // should be gone, requiring a fresh sign-up to come back.
  const { data: inactiveProfiles, error: queryError } = await adminClient
    .from('profiles')
    .select('id')
    .lt('last_active_at', cutoff.toISOString())
    .limit(MAX_DELETES_PER_RUN);

  if (queryError) {
    return new Response(JSON.stringify({ error: queryError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let deletedCount = 0;
  let failedCount = 0;
  for (const profile of inactiveProfiles ?? []) {
    // deleteUser cascades through Supabase's auth internals AND (via the
    // FK on delete cascade) this app's own profiles/daily_test_results
    // rows for that user — one call cleans up everything.
    const { error: deleteError } =
      await adminClient.auth.admin.deleteUser(profile.id);
    if (deleteError) failedCount++;
    else deletedCount++;
  }

  return new Response(
    JSON.stringify({
      checkedCutoff: cutoff.toISOString(),
      candidateCount: inactiveProfiles?.length ?? 0,
      // Counts only - never echo user ids back to the caller.
      deletedCount,
      failedCount,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
