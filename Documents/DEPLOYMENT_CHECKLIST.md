# Brain Mantra — Pre-Deployment Checklist

Everything left to do before Brain Mantra can go live on the Play Store, grouped by
area, in the order it makes sense to tackle them. ✅ = done, ⬜ = still open.
For anything involving an external dashboard (Google Play Console, AdMob,
Supabase), this doc explains *what* needs doing — when you're ready to
actually do it, tell me and I'll walk you through the real screens with you,
step by step, rather than you following written instructions alone.

---

## 1. Code & test health

- ✅ `flutter analyze` clean, all 359 tests passing (re-verified 2026-09-14).
- ✅ Core gameplay, Daily Challenge, streaks, leaderboard, ads, expanded topic
  library (Phases 0–10, `ARCHITECTURE.md` + `ROADMAP_PHASE2.md`) all built and
  tested.
- ⬜ **Server-side score validation** on `daily_test_results` writes. Right now
  a technically-savvy player could call the Supabase client directly and
  submit a fabricated score — there's no server-side check that a submitted
  score is achievable in the time given. Not a blocker for a first release
  (no real money/reward is at stake, just leaderboard bragging rights), but
  worth a Postgres trigger or Edge Function check before the leaderboard
  becomes something people care about.
- ⬜ **Manual full playthrough gate** — sign-up → Daily Challenge → leaderboard
  → restart the app → confirm everything persisted. You've been testing
  continuously on your phone, so this is likely already effectively covered,
  but it's never been checked off as one deliberate end-to-end pass.

## 2. Account deletion (Play Store hard requirement)

- ✅ In-app deletion built and deployed (`delete-own-account` Edge Function,
  confirmed `ACTIVE`) — see `ARCHITECTURE.md` §4c.
- ⬜ Public web instructions page: the old Claude Artifact link is **replaced**
  by `docs/delete-account.html` on GitHub Pages (source:
  `Documents/DELETE_ACCOUNT_PAGE.md`). Publish it and put its URL in Play
  Console — see `FOUNDER_LAUNCH_GUIDE.md` step 3.
- ⬜ **Live verification**: create a throwaway test account, delete it from
  inside the app, then confirm in the Supabase dashboard that both its
  `profiles` row and its `auth.users` row are actually gone. This is the one
  remaining check that the whole deletion pipeline — not just the function
  deploying successfully — actually works end to end. 10 minutes, best done
  together since it involves looking at live Supabase table data.

## 3. Ads (AdMob)

The real AdMob App ID and ad-unit IDs are wired in (Android). Remaining:

- ✅ **Real AdMob account created**, Brain Mantra (Android) registered in it,
  real App ID + banner/interstitial/rewarded ad unit IDs created and wired
  into `AndroidManifest.xml`/`ads_service.dart`. iOS still on TEST IDs — no
  iOS app registered in AdMob yet (Android-first).
- ✅ `AdsService` now caps ads at **PG** content rating (`maxAdContentRating`)
  and declares `AD_ID` in the manifest.
- ⬜ **Blocking controls → Sensitive categories** in the AdMob dashboard —
  additional filtering on top of the PG cap set in code.
- ⬜ **Play Console → Target Audience declaration** — choose **13 and over
  only** (not child-directed); this matches `AdsService.isChildDirectedTreatment
  = false`. Answers: `PLAY_STORE_COMPLIANCE.md`.
- ⬜ **On-device manual check** (Android — `google_mobile_ads` has no Flutter
  Web support, so this can't be checked in the Chrome dev loop): banner and
  interstitial placement, frequency (every 10 questions), and that the UMP
  consent form actually appears for an EEA/UK-simulated test device.

This whole section is genuinely one connected task — walking through the
AdMob dashboard together to create the account, register the app, and pull
the real IDs is more efficient as one live session than doing it piecemeal.

## 4. Release build signing

Code is ready (`build.gradle.kts` reads `android/key.properties`). You still:

- ⬜ **Generate the upload keystore** and fill `android/key.properties`
  (`FOUNDER_LAUNCH_GUIDE.md` step 1). Back it up in two places. Never commit it.
- ⬜ **Build the bundle:** `flutter build appbundle --release`, upload the
  `.aab` from `build/app/outputs/bundle/release/`.
- ⬜ **Enroll in Play App Signing** (default for new apps): you keep the
  upload key, Google holds the final key.
- ⬜ **Every upload needs a higher build number** — bump `version: 1.0.0+N` in
  `pubspec.yaml` (the number after `+` is Android's versionCode).

## 5. Store presence & assets

- ✅ **App icon** — the brain-and-wand logo, wired in via `flutter_launcher_icons`
  across Android/iOS/web.
- ⬜ **Screenshots** (phone, and tablet if you want tablet listing) — easiest
  captured straight off your test device once the icon/branding is final.
- ⬜ **Feature graphic** (1024×500, shown at the top of the Play listing).
- ⬜ **Store description** — short + full description, matching what the app
  actually does (Play/Daily Challenge/leaderboard/streaks — no need to
  oversell).
- ✅ **App name/package review** — renamed pre-launch: display name "Brain
  Mantra", `applicationId`/`namespace` `com.brainmantra.app` (Android),
  bundle ID `com.brainmantra.app` (iOS). Done deliberately before any
  AdMob/Play Console registration, since both register an app by package
  name.

## 6. Legal & compliance

- ✅ Privacy Policy, Terms of Service, deletion page **drafted**
  (`Documents/PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md`, `DELETE_ACCOUNT_PAGE.md`)
  and rendered to `docs/*.html` by `python tool/build_legal_pages.py`.
  In-app links added (sign-up, login, home footer, delete screen).
- ⬜ Replace `[SUPPORT_EMAIL]` and `[YOUR_COUNTRY / STATE]` in those three
  files, re-run the build script, publish `docs/` (step 3 of the guide) and
  make sure `LegalLinks.baseUrl` in `lib/utils/legal_links.dart` matches.
- ⬜ **Play Console Data Safety form** — copy answers from
  `PLAY_STORE_COMPLIANCE.md` (they match the Privacy Policy).
- ⬜ **Content rating (IARC)** — answers in `PLAY_STORE_COMPLIANCE.md`.
- ⬜ **Ads declaration** — "Yes, contains ads"; advertising ID: Yes.
- ⬜ **Supabase hardening** — `SUPABASE_SECURITY.md` (export schema, set
  `CRON_SECRET`, update cron job, deploy functions).

## 7. Submission

- ⬜ **Play Console app entry** created (if not already) and all of the above
  attached to it.
- ⬜ **Internal testing track** first — install via the internal-testing link
  yourself (and anyone else you trust) on a real device with the *real*
  signed release build, not a debug build.
- ⬜ **Closed testing** (optional but recommended) — a small group beyond
  just you, catches issues a solo tester misses.
- ⬜ **Production release** — once internal/closed testing looks clean.

---

## Suggested order

Given what's already done, a sensible path from here:

1. Flip the account-deletion Artifact public + do the live deletion
   verification (§2) — quick, and the in-app half is otherwise fully done.
2. Real AdMob account + swapped ad unit IDs + on-device check (§3) — the
   biggest remaining "external dashboard" chunk, best done as one live
   session together.
3. App icon + release signing key (§4, §5's icon item) — unblocks a real
   release build to actually test end to end.
4. Store assets + legal (§5, §6) — can happen in parallel with #3 once the
   icon exists (screenshots need the icon in them anyway).
5. Play Console submission (§7).

None of this needs to happen in one sitting — tell me which section you want
to tackle first and we'll go through the actual screens together.
