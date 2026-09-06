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

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const INACTIVITY_DAYS = 30;

Deno.serve(async (_req: Request) => {
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
    .lt('last_active_at', cutoff.toISOString());

  if (queryError) {
    return new Response(JSON.stringify({ error: queryError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const results: { id: string; deleted: boolean; error?: string }[] = [];
  for (const profile of inactiveProfiles ?? []) {
    // deleteUser cascades through Supabase's auth internals AND (via the
    // FK on delete cascade) this app's own profiles/daily_test_results
    // rows for that user — one call cleans up everything.
    const { error: deleteError } =
      await adminClient.auth.admin.deleteUser(profile.id);
    results.push({
      id: profile.id,
      deleted: !deleteError,
      error: deleteError?.message,
    });
  }

  return new Response(
    JSON.stringify({
      checkedCutoff: cutoff.toISOString(),
      candidateCount: inactiveProfiles?.length ?? 0,
      results,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
