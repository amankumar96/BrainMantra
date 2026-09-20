# Brain Mantra — Founder Launch Guide

For: the person who built this app with AI help and now wants to **publish it on Google Play
safely**, without needing a developer background. Read top to bottom once, then use the
checklist in section 3.

---

## 1. The big picture

```
 your code (this folder)
      │  flutter build appbundle
      ▼
 signed bundle  (.aab)  ── signed with YOUR upload key ──►  Google Play Console
                                                              │  internal → closed → production
                                                              ▼
                                                          players' phones
 The app on a phone talks to three outside services:
   • Supabase  = database + login + small server functions  (scores, accounts, deletion)
   • AdMob     = the ads (Google)
   • GitHub Pages = 3 public web pages: Privacy Policy, Terms, How to delete your data
```

What can break, and where:
| Piece | If it breaks… | Where to look |
|---|---|---|
| Signing | Play refuses your upload | section 4, Q1 |
| Manifest permissions | Shipped app can't reach the internet/ads | section 4, Q2 |
| Legal pages | Play rejects the listing | section 4, Q3 |
| Supabase | Login/leaderboard fail | `SUPABASE_SECURITY.md`, dashboard Logs |
| AdMob | No ads / account limited | AdMob dashboard |

---

## 2. Glossary (one line each)

- **Keystore (.jks)** — a small password-protected file holding your private signature. Like a personal wax seal.
- **Upload key** — the seal *you* use when sending builds to Google. Google keeps the real "app signing key". Lost upload key = ask Google to reset it (recoverable).
- **APK vs AAB** — APK is an installable file for testing. AAB ("app bundle") is what Play wants; Google makes per-phone APKs from it.
- **versionCode / versionName** — in `pubspec.yaml`: `version: 1.0.0+1`. `1.0.0` is what users see; the number after `+` is versionCode, which **must be higher for every upload**.
- **Manifest** — the app's ID card (`AndroidManifest.xml`): name, permissions.
- **Permission** — something the app must announce it will use (network, ad ID…).
- **RLS (Row Level Security)** — per-row bouncer rules inside the database: "you may only edit your own row".
- **anon key vs service_role key** — anon = public front-door code, safe in the app. service_role = master key, **never** in the app/Git/chat.
- **REST API** — the app asks the database questions through normal web requests. It never sends raw SQL.
- **Edge Function** — a small piece of server code on Supabase (used for account deletion).
- **Migration** — a saved SQL file that recreates your database structure.
- **UMP consent** — Google's pop-up asking EU/UK users about personalised ads.
- **AD_ID** — the phone's resettable advertising number, used by AdMob.
- **IARC** — the age-rating questionnaire in Play Console.
- **Data Safety** — the Play Console form listing what data you collect. Must match your Privacy Policy.
- **Track** — a release stage: internal → closed → production.

---

## 3. Do this, in this order

Time estimates are for a beginner. Boxes are yours to tick.

### Step 0 — Safety net (5 min)
- [ ] Turn on 2-factor authentication: Google account, GitHub, Supabase, AdMob, Play Console.
- [ ] Create a **new support email** (e.g. `brainmantra.support@gmail.com`). It will be public. Don't use your personal one.

### Step 1 — Create your signing key (15 min)  → answers Q1 below
1. Open PowerShell and run (one line; `keytool` ships with Android Studio's Java — if "not recognized", use the full path `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`):
   ```
   keytool -genkey -v -keystore $env:USERPROFILE\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. It asks for a password (twice) and your name/org/country. **Write the password down.**
3. **Back up** `upload-keystore.jks` + password: password manager *and* a cloud drive/USB. Do not put it in this project folder's Git (it is git-ignored anyway).
4. Copy `android/key.properties.example` to `android/key.properties` and fill in:
   ```
   storePassword=<your password>
   keyPassword=<your password>
   keyAlias=upload
   storeFile=C:/Users/acer/upload-keystore.jks
   ```
   (Use forward slashes.) This file is git-ignored — keep it that way.
5. Build: `flutter build appbundle --release`. Output: `build\app\outputs\bundle\release\app-release.aab`.
6. Check it's signed with *your* key (not debug): `keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab` — the owner should be the name you typed, not "Android Debug".

### Step 2 — Fill the blanks in the legal pages (10 min)
- [ ] In `Documents/PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md`, `DELETE_ACCOUNT_PAGE.md` replace `[SUPPORT_EMAIL]` with your support email and `[YOUR_COUNTRY / STATE]` with e.g. "India" / "Delhi, India".
- [ ] Re-generate the web pages: `python tool/build_legal_pages.py`.

### Step 3 — Publish the legal pages (20 min)  → answers Q3/Q4
GitHub Pages is free **only for public repositories** (your repo is private). Two options:
- **Option A (recommended): a separate public repo just for the pages.**
  1. github.com → New repository → name **`brain-mantra-legal`** → Public → create.
  2. Upload the contents of this project's `docs/` folder (index.html, privacy.html, terms.html, delete-account.html). Drag & drop in the browser works.
  3. Repo → Settings → Pages → Source: **Deploy from a branch** → branch `main`, folder `/ (root)` → Save.
  4. After ~1 minute your pages are at `https://<your-github-username>.github.io/brain-mantra-legal/privacy.html`.
- **Option B:** make the whole app repo public (then Pages → folder `/docs`). Only do this if you're fine with your code being public.

Then:
- [ ] Open the three URLs in a browser and confirm they load.
- [ ] If your address differs from the default, edit `LegalLinks.baseUrl` in `lib/utils/legal_links.dart` (must end with `/`), then rebuild.

### Step 4 — Lock down Supabase (30 min)  → see `SUPABASE_SECURITY.md`
- [ ] §3 export schema (`supabase db dump ...`) and check RLS.
- [ ] §4 set `CRON_SECRET`, update the cron job, deploy both functions, run the two tests.

### Step 5 — Google Play Console (1–2 h, plus waiting)
1. Create a developer account (one-time US$25, identity verification takes days — start early).
2. Create app: name "Brain Mantra: Maths and IQ Reasoning", App, Free.
3. Fill **App content** using `PLAY_STORE_COMPLIANCE.md`: Privacy policy URL, Ads, Advertising ID, Target audience 13+, Content rating, Data safety, Data deletion URL.
4. Store listing: description, icon, screenshots (phone), feature graphic 1024×500.
5. **AdMob**: Blocking controls → add sensitive categories to block; link the app to its Play listing after publishing.
6. Testing → **Internal testing** → Create release → upload the `.aab` → add yourself as tester → install on your phone from the opt-in link. Try sign-up, Google sign-in, Play, Daily Challenge, leaderboard, an ad, Delete Account (on a throw-away account).
7. **Closed testing**: new personal accounts need **12+ testers for 14 days** before production. Ask friends now.
8. **Production** → staged rollout starting at 20%.

### Step 6 — Every later update
1. Bump `version:` in `pubspec.yaml` (`1.0.1+2`, the number after `+` always goes up).
2. `flutter analyze` → `flutter test` → `flutter build appbundle --release`.
3. Upload to Play; roll out gradually.

---

## 4. "What does this actually mean?" — every gap explained

**Q1. "TODO: Add your own signing config" (in `build.gradle.kts`).**
Every Android app must carry a digital signature so Google and phones can tell "this update is
really from the same developer". The template used a temporary **debug** signature that every
developer's laptop makes automatically; Google refuses it. We changed the build so that when
`android/key.properties` exists it signs with *your* keystore; when it doesn't (e.g. a quick
test run), it falls back to debug so nothing breaks — but such a build can't be uploaded.
You only need to do Step 1. With Play App Signing, losing the upload key is fixable.

**Q2. "No INTERNET permission / no AD_ID".**
Android apps must list what they may use, in the manifest. `INTERNET` = may use the network.
It was only present in debug builds (it's added automatically for hot-reload), so the release
build could have shipped unable to log in or fetch ads. `AD_ID` = may read the advertising ID
(needed by AdMob on Android 13+; also declared in the Play Console). Both are now added.
Players see no extra prompt for either.

**Q3. Which Privacy Policy / Terms apply, and how do I apply them?**
- **Privacy Policy** (required): tells users what you collect, why, who else sees it, how long
  you keep it, how to delete it. Ours is written from what the code really does: Google
  sign-in (name/email), email+password (hashed by Supabase), display name, score, Daily
  Challenge results, the public leaderboard, ads/advertising ID via AdMob, 30-day inactive
  deletion, 13+ audience, GDPR/CCPA rights.
- **Terms of Service** (recommended): rules (no cheating), "for entertainment", "as-is",
  liability limits.
- **How they're applied:** the pages live at public web addresses (Step 3); the app links to
  them from sign-up, login, Home footer and the Delete screen; you paste the Privacy URL in Play
  Console. A lawyer review is worth paying for once the app earns money or gets popular.

**Q4. "Deletion page was a claude.ai artifact…" — don't we already have a Delete button?**
Yes. **Home → Delete Account** already deletes the user's login, profile and results from
Supabase (through the `delete-own-account` function) and wipes the phone's local data. That
stays exactly as is. Google additionally requires a **public web page** describing how to
delete data, because someone who already uninstalled the app can't press the button. The old
page was a temporary claude.ai link tied to a personal email; the new one (`docs/delete-account.html`)
is permanent, under your control, with a support email.

**Q5. Do we run SQL or use a REST API for rank / marks / leaderboard / deletion?**
The app never sends SQL. It calls Supabase's **REST API over HTTPS**; Supabase turns each call
into SQL on the server *after* checking Row Level Security for the logged-in user.
- Leaderboard = one request (top 10). My rank = my row + a count of higher scores.
- Marks = update of *my own* row at session end (+ Daily Challenge result row).
- Deletion = a server-side **Edge Function** using the secret admin key (that key never
  leaves Supabase). That's the correct pattern.
- Secure ✅ (HTTPS, only public key in the app, RLS) · Fast ✅ (1–2 tiny requests) · Free ✅
  (500 MB DB, 50k monthly users). Weak spot: the phone writes its own score, so a cheater
  could forge one — acceptable at launch, fix path in `SUPABASE_SECURITY.md` §5.
Details: `SUPABASE_SECURITY.md` §1.

**Q6. "Cron function callable by anyone".** The daily cleanup function used to run for anyone who
knew the (public) key. Now it needs a private secret. If you skip Step 4 the cleanup just
stops running — no harm, but old accounts won't auto-delete, which the Privacy Policy promises.

**Q7. "Database rules aren't in the project".** If Supabase were lost or you wanted to review
the rules, you'd have nothing to check. `supabase db dump` saves them (Step 4).

**Q8. Ads.** The ad SDK is now capped at PG content. Add AdMob blocking controls for extra safety.
The app targets 13+, so ads are **not** child-directed.

---

## 5. Decision helpers

- **"Is my app for children?"** No — 13+. Never tick under-13 in Play's Target Audience; that triggers the strict Families policy (special ad SDK rules).
- **"Do I share data?"** With Google AdMob (advertising ID) — yes. Supabase/Google Sign-In are service providers — not "sharing".
- **"Do I need to pay for Supabase?"** Not at launch. Check Dashboard → Usage monthly.
- **"Debug or release?"** Never upload or share a debug build. Test the signed release AAB via Internal testing.

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Play: "You uploaded a debug-signed bundle" | No `key.properties` when building | Do Step 1 and rebuild |
| Play: "Version code 1 already used" | Forgot to bump `+N` | Increase the number in `pubspec.yaml` |
| Release app can't log in / no ads | Missing permission or R8 stripping | Check merged manifest has INTERNET; run release APK and read `adb logcat` |
| Leaderboard says "could not load" | No profile row / offline | Check internet; Supabase Dashboard → Table editor → `profiles` |
| Daily cleanup returns 401 | Cron job not sending `x-cron-secret` | `SUPABASE_SECURITY.md` §4 step 4 |
| Play rejects for Privacy Policy | URL 404s or mismatch with Data Safety | Open URL in incognito; compare with `PLAY_STORE_COMPLIANCE.md` |
| App shows "Couldn't open the link" | Pages not published yet / no internet | Finish Step 3 |
| Ads don't show in testing | Ad units new (take hours) or test-device ID | Wait; check logcat "Ad failed" |

## 7. Working safely with Claude on this codebase

- Ask for small changes; commit after each: `git add -A && git commit -m "..."`.
- Before every commit: `flutter analyze` (expect "No issues found") and `flutter test` (expect all passing).
- **Never paste** keystore passwords, `service_role` keys, or `key.properties` into a chat.
- Reporting a bug: say what you tapped, what you expected, and paste the red error or a screenshot; for crashes on your phone paste `adb logcat` lines containing `flutter` or `E/`.
- Undo a bad change: `git revert <commit>` (safe) — ask Claude to do it.
- **Never commit:** `*.jks`, `key.properties`, `.env`, anything with `service_role`.

## 8. After launch

- Weekly: Play Console → Android vitals (crashes/ANRs), reviews; Supabase → Logs & Usage; AdMob earnings/policy centre.
- Read every Play policy email fully; respond within the given days.
- If you change what data you collect: update Privacy Policy → re-run `python tool/build_legal_pages.py` → re-publish pages → update Data Safety.
- **Leak checklist:** rotate the leaked key (Supabase API settings / Play upload-key reset) → redeploy functions → check Logs → tell affected users if their data was exposed.
- Calendar reminder: Supabase free projects pause after 7 days idle; unused-keystore backups verified yearly.
