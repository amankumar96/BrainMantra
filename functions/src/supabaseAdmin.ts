import { createClient } from "@supabase/supabase-js";

/**
 * Service-role Supabase client — bypasses RLS, so it can read every
 * player's `fcm_token`/`current_streak_days`/`last_played_date` and null
 * out stale tokens. Configured via Cloud Functions secrets/environment
 * config, never hardcoded and never shipped to the Flutter app (same rule
 * already documented in Documents/SUPABASE_SECURITY.md for the existing
 * delete-inactive-users Edge Function).
 *
 * Set via (once per deploy environment):
 *   firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
 *   firebase functions:config:set supabase.url="https://cmdjfvrbhqqkaxhqzfth.supabase.co"
 */
export function createSupabaseAdmin() {
  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not configured — see supabaseAdmin.ts's doc comment.",
    );
  }
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
