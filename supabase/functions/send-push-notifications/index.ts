// Sends the retention push notifications via Firebase Cloud Messaging's
// HTTP v1 API, called directly with `fetch` (no firebase-admin SDK - it
// doesn't run reliably in Deno) using a hand-rolled Google service-account
// OAuth2 flow. Triggered 5x/day by pg_cron (see
// Documents/SUPABASE_SECURITY.md, "Push notification cron setup") rather
// than Firebase Cloud Functions + Cloud Scheduler, which require the
// Blaze (paid) plan even at $0 real usage - this keeps the Firebase
// project on the free Spark plan with no credit card anywhere. FCM
// message delivery itself is free and unlimited on every Firebase plan;
// only Google's own scheduler is paid-plan-gated, not push notifications.
//
// Called with a JSON body of {"kind": "generic"} or {"kind": "streak"} -
// one endpoint, two modes, same shape as this project's other single-
// purpose cron functions.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

// Hand-ported copy of Flutter's `_mathFacts`/`mathFactForDay` in
// lib/services/notification_service.dart. KEEP THESE TWO LISTS IN SYNC -
// there is no single-sourcing between the Dart app and this Edge Function.
const MATH_FACTS: string[] = [
  'Pythagoras led a secret society that banned eating beans.',
  'Euler kept producing major math work after going completely blind.',
  "Zero as a number wasn't widely used in Europe until the 1200s.",
  'The "=" sign was invented because its creator was tired of writing "is equal to" by hand.',
  'Ramanujan taught himself advanced mathematics from a single old textbook.',
  "Fibonacci's famous sequence first appeared in a problem about rabbit breeding.",
  'Archimedes reportedly ran through the streets shouting "Eureka!" after a bathtub discovery.',
  'As a schoolboy, Gauss summed 1 to 100 in seconds by pairing up numbers.',
  'The word "algebra" comes from Arabic "al-jabr", meaning "reunion of broken parts".',
  'Newton and Leibniz each invented calculus independently, sparking a bitter rivalry.',
  'Ada Lovelace wrote the first published computer algorithm — in the 1840s.',
  'Pi has trillions of calculated digits, but about 39 are enough for any real-world measurement.',
  'The Babylonians used a base-60 number system — why an hour has 60 minutes.',
  'Alan Turing helped crack wartime codes and laid the groundwork for computer science.',
  'A "googol" (1 followed by 100 zeros) got its name from a mathematician\'s 9-year-old nephew.',
];

function mathFactForDay(now: Date): string {
  const startOfYear = Date.UTC(now.getUTCFullYear(), 0, 1);
  const dayOfYear = Math.floor(
    (Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) -
      startOfYear) /
      86400000,
  );
  return MATH_FACTS[dayOfYear % MATH_FACTS.length];
}

// Same constant-time header check as delete-inactive-users/index.ts.
function constantTimeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

// ---- Google service-account OAuth2, by hand (no SDK — Deno Web Crypto) ----

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

function base64url(bytes: Uint8Array): string {
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importServiceAccountKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binaryDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/**
 * Exchanges the Firebase service-account key (see
 * Documents/SUPABASE_SECURITY.md) for a short-lived FCM access token, via
 * Google's standard JWT Bearer OAuth2 flow — the same thing firebase-admin
 * does internally, done by hand since that SDK doesn't run reliably here.
 */
async function getFcmAccessToken(
  clientEmail: string,
  privateKeyPem: string,
): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: clientEmail,
    scope: FCM_SCOPE,
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSec,
    exp: nowSec + 3600,
  };
  const enc = new TextEncoder();
  const signingInput =
    base64url(enc.encode(JSON.stringify(header))) +
    '.' +
    base64url(enc.encode(JSON.stringify(claims)));
  const key = await importServiceAccountKey(privateKeyPem);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    enc.encode(signingInput),
  );
  const jwt = `${signingInput}.${base64url(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!response.ok) {
    throw new Error(
      `FCM OAuth token exchange failed: ${response.status} ${await response.text()}`,
    );
  }
  const json = await response.json();
  return json.access_token as string;
}

/** Sends one FCM v1 message; reports whether the token is stale (no longer registered). */
async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  message: Record<string, unknown>,
): Promise<{ ok: boolean; stale: boolean }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message }),
    },
  );
  if (response.ok) return { ok: true, stale: false };
  // FCM v1 returns 404 NOT_FOUND for a token that's no longer registered
  // (app uninstalled, data cleared, etc.) — see Google's FCM REST
  // reference for SendMessageErrorCode.UNREGISTERED.
  return { ok: false, stale: response.status === 404 };
}

Deno.serve(async (req: Request) => {
  const jsonHeaders = { 'Content-Type': 'application/json' };

  const expectedSecret = Deno.env.get('CRON_SECRET');
  if (!expectedSecret) {
    return new Response(JSON.stringify({ error: 'Server not configured' }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
  const providedSecret = req.headers.get('x-cron-secret') ?? '';
  if (!constantTimeEqual(providedSecret, expectedSecret)) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const { kind } = await req.json().catch(() => ({ kind: undefined }));
  if (kind !== 'generic' && kind !== 'streak') {
    return new Response(
      JSON.stringify({ error: 'kind must be "generic" or "streak"' }),
      { status: 400, headers: jsonHeaders },
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  // Prefers the new APP_SECRET_KEY over the legacy auto-injected
  // SUPABASE_SERVICE_ROLE_KEY (kept only as a migration fallback — see
  // delete-inactive-users/index.ts's doc comment for why, including why
  // it's APP_SECRET_KEY and not SUPABASE_SECRET_KEY).
  const serviceRoleKey = Deno.env.get('APP_SECRET_KEY') ??
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const fcmProjectId = Deno.env.get('FCM_PROJECT_ID')!;
  const fcmClientEmail = Deno.env.get('FCM_CLIENT_EMAIL')!;
  // Vault/secrets storage round-trips literal "\n" for multiline values —
  // restore real newlines before handing this to Web Crypto.
  const fcmPrivateKey = Deno.env.get('FCM_PRIVATE_KEY')!.replace(/\\n/g, '\n');
  const accessToken = await getFcmAccessToken(fcmClientEmail, fcmPrivateKey);

  const MASCOT_NEUTRAL_URL = `${supabaseUrl}/storage/v1/object/public/push-assets/mascot_transparent.png`;
  const MASCOT_WORRIED_URL = `${supabaseUrl}/storage/v1/object/public/push-assets/mascot_worried_transparent.png`;

  let sentCount = 0;
  let staleCount = 0;
  const staleIds: string[] = [];

  if (kind === 'generic') {
    const { data, error } = await adminClient
      .from('profiles')
      .select('id, fcm_token')
      .not('fcm_token', 'is', null);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: jsonHeaders,
      });
    }
    const fact = mathFactForDay(new Date());
    for (const row of data ?? []) {
      const result = await sendFcmMessage(accessToken, fcmProjectId, {
        token: row.fcm_token,
        notification: {
          title: 'Brain Mantra 🧠',
          body: `${fact} Come play a round!`,
        },
        android: { notification: { image: MASCOT_NEUTRAL_URL } },
      });
      if (result.ok) sentCount++;
      else if (result.stale) {
        staleCount++;
        staleIds.push(row.id);
      }
    }
  } else {
    const todayUtc = new Date().toISOString().slice(0, 10);
    const { data, error } = await adminClient
      .from('profiles')
      .select('id, fcm_token, current_streak_days')
      .not('fcm_token', 'is', null)
      .gt('current_streak_days', 0)
      .or(`last_played_date.is.null,last_played_date.lt.${todayUtc}`);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: jsonHeaders,
      });
    }
    for (const row of data ?? []) {
      const result = await sendFcmMessage(accessToken, fcmProjectId, {
        token: row.fcm_token,
        notification: {
          title: 'Brain Mantra 😟',
          body: `Your ${row.current_streak_days}-day streak is about to end! Play now to keep it alive.`,
        },
        android: { notification: { image: MASCOT_WORRIED_URL } },
      });
      if (result.ok) sentCount++;
      else if (result.stale) {
        staleCount++;
        staleIds.push(row.id);
      }
    }
  }

  if (staleIds.length > 0) {
    await adminClient.from('profiles').update({ fcm_token: null }).in(
      'id',
      staleIds,
    );
  }

  return new Response(JSON.stringify({ kind, sentCount, staleCount }), {
    headers: jsonHeaders,
  });
});
