# Brain Mantra — Supabase Security Guide (for a non-expert founder)

Supabase is your **database + login system + small server functions**, hosted for you
(the free plan is enough at launch). This guide explains what protects it, what we found
missing, and the exact steps to fix it. You never need to write code — you copy, paste and click.

---

## 1. How the app talks to Supabase (so you know what to protect)

The app **never sends raw SQL**. It uses Supabase's built-in **REST API** (called PostgREST)
over **HTTPS**. A line like `.from('profiles').select().order('current_score')` in Dart
becomes a web request `GET https://<project>.supabase.co/rest/v1/profiles?...`. On the
server, Postgres runs the real SQL — but only **after checking the Row Level Security (RLS)
rules for whoever is logged in** (identified by their login token, a "JWT").

| Feature | What the app does | Where the rule is enforced |
|---|---|---|
| Login | Supabase Auth (Google ID token, or email + password) | Supabase Auth |
| Leaderboard | REST `select` top 10 by `current_score`, active in last 30 days | RLS on `profiles` |
| My rank | REST `select` my row + REST `count` of players with a higher score | RLS on `profiles` |
| Update marks | REST `update` of **my own** `profiles` row at session end; `upsert` into `daily_test_results` for Daily Challenge | RLS on both tables |
| Delete account | Calls the **Edge Function** `delete-own-account` (server code) | The function checks your login token |
| Delete inactive (30 days) | Edge Function `delete-inactive-users`, run daily by a scheduler | A private secret (added in this release) |

**Is it secure / fast / free?**
- *Secure*: traffic is encrypted; only the **public "anon" key** is inside the app (that is
  normal — like a hotel's front-door code: useless unless RLS lets you in). The **secret
  `service_role` key** is only used inside Edge Functions on Supabase's servers. We checked:
  it is **not** in the app or the repo. ✅
- *Fast*: each screen makes 1–2 tiny requests.
- *Free*: the free plan gives 500 MB database, 50,000 monthly active users, 500k function
  calls — far above launch needs. Caveat: free projects **pause after ~7 days of no
  activity** — open the dashboard now and then, or upgrade later.

> Golden rule: the **anon key may be public. The service_role key must NEVER appear in the
> app, in Git, in a screenshot, or in a chat.** If it leaks: Dashboard → Project Settings →
> API → regenerate it immediately.

---

## 2. What we found (in plain English)

| # | Finding | Why it matters | Status |
|---|---|---|---|
| S1 | Database rules (tables + RLS) were typed into the website, **not saved in the project** | If the project is lost you can't rebuild; nobody can review the rules | **You must export them** (section 3) |
| S2 | `delete-inactive-users` could be triggered by **anyone holding the public key** | A stranger could run your cleanup job on demand | **Fixed in code**; you must set a secret + update the scheduler (section 4) |
| S3 | The phone writes its own `current_score` | A determined cheater can give themselves any score | Proposal in section 5; accepted risk for v1 |
| S4 | The old view `leaderboard_last_30_days` is unused but may still exist | Unused objects with wrong permissions can leak data | Drop it (section 3) |
| S5 | Edge functions imported a floating library version | A surprise update could change behaviour | **Fixed in code** (pinned 2.45.4) — test after deploying |

---

## 3. Export your database rules into the project (S1, S4)

1. Log in and link the Supabase CLI once (you already use it to deploy functions):
   ```
   supabase login
   supabase link --project-ref cmdjfvrbhqqkaxhqzfth
   ```
2. Export structure + rules:
   ```
   supabase db dump --schema public -f supabase/migrations/0001_baseline.sql
   ```
   (You may be asked for the database password: Dashboard → Project Settings → Database.)
3. Open the file and **verify these five things** (or paste it to Claude and ask):
   - [ ] Every table (`profiles`, `daily_test_results`) has `ENABLE ROW LEVEL SECURITY`.
   - [ ] `profiles` has a **SELECT** policy (everyone can read display name + score — needed for the leaderboard).
   - [ ] `profiles` INSERT/UPDATE policies say `auth.uid() = id` **including the `with check` part**.
   - [ ] `daily_test_results` write policies say `auth.uid() = user_id`.
   - [ ] No `GRANT ... TO anon` gives write access.
4. Dashboard check: **Authentication → Policies** — every table should show "RLS enabled".
   A table with RLS disabled is readable and writable by anyone holding the public key. Enable it *now*.
5. Drop the unused view: SQL Editor → `drop view if exists public.leaderboard_last_30_days;`
6. Commit: `git add supabase/migrations && git commit -m "Add baseline schema and RLS"`.

---

## 4. Lock down the daily cleanup job (S2) — do these IN ORDER

The function now refuses to run unless the caller sends a private header `x-cron-secret`.
**If you deploy the function before updating the scheduler, the daily cleanup just starts
returning 401 — nothing is wrongly deleted, it simply stops running.** So order matters:

1. **Pick a long random secret** (32+ chars). PowerShell generator:
   `-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 40 | % {[char]$_})`
   Save it in your password manager.
2. **Give it to the function:**
   ```
   supabase secrets set CRON_SECRET=<your-secret> --project-ref cmdjfvrbhqqkaxhqzfth
   ```
3. **Store it in Vault for the scheduler** (Dashboard → SQL Editor):
   ```sql
   select vault.create_secret('<your-secret>', 'cron_secret');
   ```
4. **Update the scheduled job** so it sends the header. First look at the current one:
   `select jobid, command from cron.job where jobname = 'delete-inactive-users-daily';`
   Then re-create it (keep your existing `project_url` / `publishable_key` secret names):
   ```sql
   select cron.unschedule('delete-inactive-users-daily');
   select cron.schedule(
     'delete-inactive-users-daily',
     '0 3 * * *',
     $job$
     select net.http_post(
       url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
              || '/functions/v1/delete-inactive-users',
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'Authorization', 'Bearer ' ||
           (select decrypted_secret from vault.decrypted_secrets where name = 'publishable_key'),
         'x-cron-secret',
           (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
       ),
       body := '{}'::jsonb
     );
     $job$
   );
   ```
5. **Deploy the new functions:**
   ```
   supabase functions deploy delete-inactive-users --project-ref cmdjfvrbhqqkaxhqzfth
   supabase functions deploy delete-own-account --project-ref cmdjfvrbhqqkaxhqzfth
   ```
6. **Test it** (PowerShell; fill in the values):
   - Without the header → expect **401**:
     `curl.exe -i -X POST https://cmdjfvrbhqqkaxhqzfth.supabase.co/functions/v1/delete-inactive-users -H "Authorization: Bearer <anon key>"`
   - With `-H "x-cron-secret: <your-secret>"` → expect **200** and JSON with `deletedCount`.
7. In the app, delete a **throw-away account** (Home → Delete Account) to confirm
   `delete-own-account` still works after the library pin.

---

## 5. Stop score cheating (S3) — optional, recommended soon after launch

Today the phone says "my score is now X" and the server believes it. Two levels of fix:

- **Level 1 (10 minutes):** run `supabase/proposed/0002_score_guard.sql` in the SQL Editor.
  A player then can't change their score by more than 2000 in one update. Read the comments
  in the file first and tune the number.
- **Level 2 (proper, later):** a Postgres function (`rpc`) such as `submit_session(...)` that
  recomputes marks **on the server**, updates the score and returns the new rank in one
  call — faster *and* cheat-resistant. Ask Claude: *"Design and implement the
  submit_session RPC for Brain Mantra"* when you're ready; it touches app and database together.

For a first release with no money or prizes at stake, Level 1 is a sensible middle ground.

---

## 6. Everyday security habits

- Never commit `key.properties`, `.jks` files, `.env`, or anything containing `service_role`
  (`.gitignore` now blocks the common ones).
- Never paste secrets into chats or screenshots. If you did: rotate it.
- Keep **Confirm email = ON** (it is).
- Turn on **2-factor authentication** for Supabase, Google Play Console, AdMob, GitHub and your Google account.
- After launch, every few weeks: Dashboard → **Logs** (API and Edge Functions) — look for error spikes or odd traffic.
- If data may have leaked: rotate keys → redeploy functions → notify affected users → update the Privacy Policy if needed.
