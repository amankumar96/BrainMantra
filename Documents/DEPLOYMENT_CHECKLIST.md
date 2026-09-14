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
- ✅ Public web instructions page published as a Claude Artifact, flipped to
  public/shared via its share menu, and republished with both the current
  corner-button deletion flow and Brain Mantra branding (§4c).
- ⬜ **Live verification**: create a throwaway test account, delete it from
  inside the app, then confirm in the Supabase dashboard that both its
  `profiles` row and its `auth.users` row are actually gone. This is the one
  remaining check that the whole deletion pipeline — not just the function
  deploying successfully — actually works end to end. 10 minutes, best done
  together since it involves looking at live Supabase table data.

## 3. Ads (AdMob)

Currently running entirely on Google's published **TEST** ad-unit IDs (banner,
interstitial, rewarded) and a TEST App ID in `AndroidManifest.xml` — this is
deliberate and safe for development (serving real ads without a real AdMob
account risks getting your future account banned), but every one of these
needs to be swapped before a release build:

- ✅ **Real AdMob account created**, Brain Mantra (Android) registered in it,
  real App ID + banner/interstitial/rewarded ad unit IDs created and wired
  into `AndroidManifest.xml`/`ads_service.dart`. iOS still on TEST IDs — no
  iOS app registered in AdMob yet (Android-first).
- ⬜ **Blocking controls → Sensitive categories** in the AdMob dashboard —
  this is where content/sensitivity filtering is handled for this app (by
  deliberate design, `AdsService` sets no `maxAdContentRating` in code).
- ⬜ **Play Console → Target Audience declaration** — a business/legal
  decision about who the app is aimed at; `AdsService.isChildDirectedTreatment`
  is a single flag to flip if that declaration ever includes children.
- ⬜ **On-device manual check** (Android — `google_mobile_ads` has no Flutter
  Web support, so this can't be checked in the Chrome dev loop): banner and
  interstitial placement, frequency (every 10 questions), and that the UMP
  consent form actually appears for an EEA/UK-simulated test device.

This whole section is genuinely one connected task — walking through the
AdMob dashboard together to create the account, register the app, and pull
the real IDs is more efficient as one live session than doing it piecemeal.

## 4. Release build signing

- ⬜ **Generate a real release signing key** — right now
  `android/app/build.gradle.kts` signs release builds with the *debug* key
  (there's a `// TODO` marking exactly this), which works for `flutter run
  --release` locally but Google will reject or you'll be unable to publish
  updates later with a debug-signed build.
- ⬜ **Enroll in Play App Signing** (Google's recommended approach — you keep
  an upload key, Google manages the final signing key, so a lost local key
  doesn't permanently lock you out of updating the app).

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

- ⬜ **Privacy Policy** — must be hosted at a public URL (this can reuse the
  same Claude Artifact approach as the account-deletion page, or any static
  host) and must accurately describe what Brain Mantra actually collects
  (email, display name, score/streak history) and how account deletion
  works.
- ⬜ **Play Console Data Safety form** — must match the Privacy Policy
  exactly; Google spot-checks for mismatches and will reject/suspend for
  them.
- ⬜ **Content rating questionnaire** (Play Console) — a short form about the
  app's content; for a math quiz game this should be straightforward.
- ⬜ **Ads declaration** in Play Console (the app does show ads — this must
  be declared truthfully).

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
