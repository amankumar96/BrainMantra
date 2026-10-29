import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import type { Message } from "firebase-admin/messaging";

import { mathFactForDay } from "./mathFacts";
import { createSupabaseAdmin } from "./supabaseAdmin";

admin.initializeApp();

// Public URLs of the two mascot images, uploaded to a public Supabase
// Storage bucket (see the feature plan's "Image hosting" section) —
// Android's AndroidNotification.imageUrl must be a public HTTPS URL,
// bundled Flutter assets aren't reachable from a server payload.
const SUPABASE_PROJECT_URL = "https://cmdjfvrbhqqkaxhqzfth.supabase.co";
const MASCOT_NEUTRAL_URL = `${SUPABASE_PROJECT_URL}/storage/v1/object/public/push-assets/mascot_transparent.png`;
const MASCOT_WORRIED_URL = `${SUPABASE_PROJECT_URL}/storage/v1/object/public/push-assets/mascot_worried_transparent.png`;

// Shared secret for the manual HTTP test-trigger endpoints below — mirrors
// the x-cron-secret pattern already used by
// supabase/functions/delete-inactive-users/index.ts. Set via:
//   firebase functions:secrets:set PUSH_TEST_SECRET
const TEST_TRIGGER_HEADER = "x-push-test-secret";

/** FCM allows at most 500 tokens per sendEachForMulticast call. */
function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

/**
 * Sends the same message body to every token, chunked to FCM's 500-token
 * multicast limit, and nulls out any token FCM reports as no longer
 * registered (uninstalled app, cleared data, etc.).
 */
async function sendToTokens(
  tokens: string[],
  body: Omit<Message, "token">,
): Promise<void> {
  if (tokens.length === 0) return;
  const staleTokens: string[] = [];
  for (const batch of chunk(tokens, 500)) {
    const response = await admin
      .messaging()
      .sendEachForMulticast({ tokens: batch, ...body });
    response.responses.forEach((r, i) => {
      if (
        !r.success &&
        r.error?.code === "messaging/registration-token-not-registered"
      ) {
        staleTokens.push(batch[i]);
      }
    });
  }
  if (staleTokens.length > 0) {
    const supabase = createSupabaseAdmin();
    await supabase
      .from("profiles")
      .update({ fcm_token: null })
      .in("fcm_token", staleTokens);
  }
}

async function sendGenericPush(): Promise<void> {
  const supabase = createSupabaseAdmin();
  const { data, error } = await supabase
    .from("profiles")
    .select("fcm_token")
    .not("fcm_token", "is", null);
  if (error) throw error;

  const tokens = (data ?? [])
    .map((row) => row.fcm_token as string | null)
    .filter((t): t is string => !!t);
  const fact = mathFactForDay(new Date());

  await sendToTokens(tokens, {
    notification: {
      title: "Brain Mantra 🧠",
      body: `${fact} Come play a round!`,
    },
    android: {
      notification: {
        imageUrl: MASCOT_NEUTRAL_URL,
      },
    },
  });
}

async function sendStreakPush(): Promise<void> {
  const supabase = createSupabaseAdmin();
  const todayUtc = new Date().toISOString().slice(0, 10);
  const { data, error } = await supabase
    .from("profiles")
    .select("fcm_token, current_streak_days, last_played_date")
    .not("fcm_token", "is", null)
    .gt("current_streak_days", 0)
    .or(`last_played_date.is.null,last_played_date.lt.${todayUtc}`);
  if (error) throw error;

  const tokens: string[] = [];
  const messages = new Map<string, Message>();
  for (const row of data ?? []) {
    const token = row.fcm_token as string | null;
    if (!token) continue;
    const streak = row.current_streak_days as number;
    tokens.push(token);
    messages.set(token, {
      token,
      notification: {
        title: "Brain Mantra 😟",
        body: `Your ${streak}-day streak is about to end! Play now to keep it alive.`,
      },
      android: {
        notification: {
          imageUrl: MASCOT_WORRIED_URL,
        },
      },
    });
  }

  // Streak copy is personalized per user (the streak count), unlike the
  // generic push — send one at a time rather than batching through the
  // shared-body multicast helper above.
  const staleTokens: string[] = [];
  for (const token of tokens) {
    try {
      await admin.messaging().send(messages.get(token)!);
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === "messaging/registration-token-not-registered") {
        staleTokens.push(token);
      }
    }
  }
  if (staleTokens.length > 0) {
    await supabase
      .from("profiles")
      .update({ fcm_token: null })
      .in("fcm_token", staleTokens);
  }
}

const TIME_ZONE = "Asia/Kolkata";

export const genericPush1 = onSchedule(
  { schedule: "0 9 * * *", timeZone: TIME_ZONE },
  () => sendGenericPush(),
);
export const genericPush2 = onSchedule(
  { schedule: "30 13 * * *", timeZone: TIME_ZONE },
  () => sendGenericPush(),
);
export const genericPush3 = onSchedule(
  { schedule: "30 20 * * *", timeZone: TIME_ZONE },
  () => sendGenericPush(),
);
export const streakPush1 = onSchedule(
  { schedule: "0 17 * * *", timeZone: TIME_ZONE },
  () => sendStreakPush(),
);
export const streakPush2 = onSchedule(
  { schedule: "0 21 * * *", timeZone: TIME_ZONE },
  () => sendStreakPush(),
);

// Manual test triggers — curl these to verify behavior without waiting for
// the schedule. Guarded by a secret header, same risk profile as the
// existing x-cron-secret-guarded delete-inactive-users function.
export const testSendGeneric = onRequest(async (req, res) => {
  if (req.get(TEST_TRIGGER_HEADER) !== process.env.PUSH_TEST_SECRET) {
    res.status(401).send("unauthorized");
    return;
  }
  await sendGenericPush();
  res.status(200).send("ok");
});

export const testSendStreak = onRequest(async (req, res) => {
  if (req.get(TEST_TRIGGER_HEADER) !== process.env.PUSH_TEST_SECRET) {
    res.status(401).send("unauthorized");
    return;
  }
  await sendStreakPush();
  res.status(200).send("ok");
});
