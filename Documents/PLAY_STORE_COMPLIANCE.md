# Brain Mantra — Google Play Compliance Pack

Copy-paste answers for the Play Console forms, plus a plain-English explanation of every
gap found in the pre-launch audit. Everything is written for **Brain Mantra: Maths and IQ
Reasoning**, package `com.brainmantra.app`, audience **13+ (general, not child-directed)**.

> I'm an AI assistant, not a lawyer. These answers match what the app really does today.
> If you add a feature that collects new data (analytics, crash reporting, chat, purchases),
> update the Privacy Policy **and** the Data Safety form. Google compares them.

---

## 1. The gaps — "Explain it to me"

| # | Finding | Plain English | Fixed? |
|---|---|---|---|
| 1 | Release build signed with the **debug key** | Android apps need a personal signature so Google knows updates come from you. The debug one is a free throw-away stamp Google refuses. | Code fixed. **You** create the keystore (Guide step 1). |
| 2 | No **INTERNET** permission in the main manifest | Android apps must announce in advance "I use the network". Debug builds get it for free; release builds don't. Without it a shipped app could fail to log in or load ads. | ✅ Fixed |
| 3 | No **AD_ID** permission | Since Android 13 an app using ads must declare it reads the resettable advertising ID. Play Console also asks you. | ✅ Fixed (+ you answer the form) |
| 4 | No Privacy Policy / Terms | Google *requires* a public Privacy Policy link (store listing + in-app) because the app handles names/emails and shows ads. Terms protect you (no cheating, "as-is"). | ✅ Drafted, in-app links added. **You** fill 2 blanks + publish (Guide step 3). |
| 5 | Deletion page was a claude.ai artifact with a personal email | The in-app **Delete Account** button already works and stays. Google *also* wants a public web page for people who uninstalled the app. It must be a permanent link you own. | ✅ Replaced by `docs/delete-account.html`; **you** publish + choose a support email. |
| 6 | `delete-inactive-users` open to anyone with the public key | The public key is in every copy of the app. That function needs a private password instead. | Code fixed. **You** set the secret + deploy (`SUPABASE_SECURITY.md` §4). |
| 7 | Database rules not saved in the repo | Rules typed into a website can't be reviewed or rebuilt. | **You** run `supabase db dump` (`SUPABASE_SECURITY.md` §3). |
| 8 | Client-written score | A cheater can send any score. Fine for v1 (no prizes); mitigation proposed. | Proposal in `supabase/proposed/`. |
| 9 | No ad content-rating cap | Without a cap, mature ads could show to a 13+ audience. | ✅ PG cap in code; add AdMob blocking controls. |
| 10 | Cloud backup of app data allowed | Android could back a player's local data up to Google Drive. Off is safer. | ✅ `allowBackup=false` |

---

## 2. Store listing basics

- **App category:** Education (or Trivia/Puzzle — Education is fine for a maths game).
- **Privacy Policy URL:** `<your Pages URL>/privacy.html` (must match `LegalLinks` in the app).
- **Contact email:** your dedicated support email (not personal — it's public).
- **Account deletion URL** (App content → Data safety → "Data deletion"): `<your Pages URL>/delete-account.html`.
- **Ads:** Yes, contains ads.

---

## 3. Target audience and content

- **Target age groups:** tick **13–15**, **16–17**, **18 and over**. Do **not** tick anything under 13.
  (Ticking under-13 pulls you into the Families policy with much stricter ad/SDK rules.)
- **Does the app appeal to children?** No (it's a maths and reasoning quiz for teens/adults).
  Be honest — Google judges by look and feel too. Plain, non-cartoon design helps.
- Matches the code: `AdsService.isChildDirectedTreatment = false`.

## 4. Ads declaration

- "Does your app contain ads?" → **Yes**.
- Advertising ID (App content → Advertising ID): **Yes, the app uses the advertising ID**, purpose **Advertising or marketing**. (Matches the `AD_ID` permission.)

## 5. Content rating (IARC questionnaire)

Category: **Reference, News, or Educational** (or "Game" → Trivia). Answer **No** to every
question about violence, blood, sexual content, profanity, controlled substances,
gambling (real or simulated), and horror. Answer:
- User-generated content shared between users? **No** (only display name + score on a leaderboard; no free text messaging).
- Users can interact/communicate? **No**.
- Shares user location? **No**.
- Allows purchases? **No**.
- Ads? contains ads → **Yes** (this doesn't raise the rating).

Expected outcome: **Everyone / PEGI 3-ish**; your own audience declaration still says 13+.

## 6. Data safety form

"Does your app collect or share user data?" → **Yes**. "Is all data encrypted in transit?" → **Yes** (HTTPS). "Can users request data deletion?" → **Yes** (in-app + web URL).

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Personal info → **Name** (display name / Google name) | Yes | No* | App functionality, Account management | Required |
| Personal info → **Email address** | Yes | No | Account management | Required |
| App activity → **Other user-generated / in-app actions** (score, Daily Challenge results) | Yes | No | App functionality | Required |
| Device or other IDs → **Advertising ID** | Yes (by AdMob) | **Yes** (with Google AdMob) | Advertising or marketing | Required for ads |
| App info and performance / Diagnostics | **No** (no crash reporting SDK yet) | — | — | — |
| Location, contacts, photos, financial, health | **No** | — | — | — |

\* The display name is visible to other players on the leaderboard, but that is in-app
display, not sharing with a third party. Supabase and Google act as **service providers**
processing on our behalf — Play does not count that as "sharing".

AdMob also collects IP/device/usage data to serve ads. In the console, for **Google Mobile
Ads SDK** Google's own guidance lists: Device or other IDs, App interactions (ad
interactions), Crash logs and Diagnostics, Approximate location. Declare those under
"shared with Google AdMob" if the console's SDK helper shows them, to stay conservative.

## 7. Pre-launch testing path

1. **Internal testing** (up to 100 testers, no review wait): upload the signed AAB, add your
   Gmail as a tester, install via the opt-in link on your phone.
2. **Pre-launch report** (Play runs the app on real devices automatically): read crashes and
   accessibility warnings.
3. **Closed testing**: NEW personal developer accounts must run a closed test with
   **≥12 testers for 14 consecutive days** before production access. Recruit friends early.
4. **Production** → staged rollout (start 20%).

## 8. Keys, incidents

- **Upload key lost?** Play Console → Setup → App signing → "Request upload key reset". It
  takes a few days. Don't panic — Google holds the real signing key.
- **Upload key leaked?** Same reset flow, then generate a new keystore.
- **Supabase `service_role` key leaked?** Regenerate in Dashboard → Project Settings → API,
  update Edge Function secrets, redeploy.
- **Policy warning email:** read it fully, fix, reply through the Play Console appeal form —
  do not create a second developer account.
