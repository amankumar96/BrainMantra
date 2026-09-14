# Brain Mantra — A Lead Developer's Guide to This Project

This document exists to teach *you* how this application was built — not as
a feature log (that's `ARCHITECTURE.md` and `ROADMAP_PHASE2.md`), but as a
walkthrough of the tools, languages, and engineering judgment behind it, the
way you'd onboard a new engineering lead taking this project over. Read it
once end to end, then keep it as a reference.

---

## 1. What was actually built

**Brain Mantra** (built under the working name "MathBlitz," renamed
pre-launch) is a cross-platform (Android-first, iOS-capable) mobile math
and reasoning quiz game, built with Flutter. In plain terms, a player:

- Signs up (email/password or Google Sign-In) or plays as a guest locally.
- Plays timed math/reasoning questions across 13+ topics — arithmetic,
  BODMAS, speed/distance, profit & loss, simple/compound interest, geometry
  (angle-finding, area/volume, perimeter), probability, ratio, coordinate
  geometry, bar-graph reading, family-tree reasoning, and shape
  identification — with difficulty auto-scaling to the player's score.
- Earns a persistent score that survives across sessions (stored both
  locally and in the cloud).
- Plays a once-a-day "Daily Challenge" with a date-seeded question set so
  every player who plays *today* sees the exact same questions — fair
  competition for a shared leaderboard.
- Builds a day-streak for returning daily.
- Sees banner/interstitial/rewarded ads (monetization).
- Can delete their account and all associated data at any time, in-app.

Under the hood, this is really **two applications working together**:

1. A **Flutter client app** (all of `lib/`) — everything the player sees and
   touches, plus all the game logic (question generation, scoring,
   difficulty).
2. A **Supabase backend** (`supabase/`) — a hosted Postgres database plus a
   small amount of server-side code, handling accounts, persistent scores,
   the leaderboard, and account deletion.

---

## 2. Languages — what each one did, and where

| Language | Where | What it did |
|---|---|---|
| **Dart** | `lib/`, `test/` (all of it) | The entire client application — UI screens, widgets, business logic (puzzle generators, scoring, streaks), and every automated test. Dart is Flutter's one and only language; there's no separate "frontend language" the way a web app splits HTML/CSS/JS. |
| **SQL** | Written ad hoc against the Supabase Postgres database (not checked into the repo as migration files — run directly via the Supabase SQL editor or `supabase db query`) | Table schemas (`profiles`, `daily_test_results`), Row-Level Security (RLS) policies (the rules that stop one player's client from reading or editing another player's data), and the `on delete cascade` foreign keys that make account deletion actually remove *everything* tied to a user. |
| **TypeScript, on Deno** | `supabase/functions/*/index.ts` | The two server-side Edge Functions: `delete-inactive-users` (a scheduled cleanup job) and `delete-own-account` (the account-deletion endpoint the app calls). Supabase Edge Functions run on Deno, not Node.js — same TypeScript language, different runtime, no `npm`/`package.json` involved. |
| **YAML** | `pubspec.yaml`, `analysis_options.yaml` | `pubspec.yaml` is Dart/Flutter's equivalent of `package.json` — declares every third-party package the app depends on and their version constraints. `analysis_options.yaml` configures `flutter analyze`'s lint rules (which coding-style/correctness issues get flagged). |
| **Kotlin / Gradle Kotlin DSL** | `android/app/build.gradle.kts` and friends | Android's own build configuration — package name (`applicationId`), SDK version targets, and (still pending, see `DEPLOYMENT_CHECKLIST.md`) the release signing setup. This is boilerplate Flutter generates for you; you very rarely hand-write Kotlin for a Flutter app unless you need a native Android feature Flutter doesn't expose. |
| **Markdown** | `ARCHITECTURE.md`, `ROADMAP_PHASE2.md`, `DEPLOYMENT_CHECKLIST.md`, this file, `README.md` | Living project documentation — the actual spec the app was built against, updated as a real design document rather than left to rot once the code shipped. |

**Why Dart/Flutter at all?** One codebase compiles to real native Android
*and* iOS apps (and web, though this project doesn't ship that), instead of
maintaining separate Kotlin/Swift codebases. The trade-off is that Flutter
apps are a bit larger and the ecosystem is younger than native, but for a
single-developer or small-team project the "write once" leverage is large.

---

## 3. Tools — what each one is, and what it actually did here

### Development
- **Flutter SDK** — the framework itself: the widget system, the rendering
  engine, the build toolchain (`flutter build apk`, `flutter run`, etc.).
  Everything visual in the app is a tree of Flutter *widgets*.
- **Dart SDK** (ships with Flutter) — the compiler/language runtime.
- **Claude Code** (this CLI) — used as the primary development tool for this
  project: writing/editing every file, running the test suite, running git
  commands, and reasoning through architecture decisions recorded in
  `ARCHITECTURE.md`.
- **VS Code / an IDE** — for you to browse, read, and manually edit the code
  outside of a Claude Code session; also where `flutter run` gets launched
  against a connected device or emulator during interactive testing.

### Version control
- **Git** — every change to this codebase is a commit; `git log` is a full,
  readable history of how the app was actually built, in order.
- **GitHub** (`git@github.com:amankumar96/Maths_test.git`) — where the git
  repository is hosted remotely. Private repo, `main` is the only branch in
  active use. `gh` (GitHub's CLI) is available for anything beyond plain git
  (PRs, issues) though this project hasn't needed pull requests yet, working
  directly on `main`.

### Backend
- **Supabase** — a "Backend-as-a-Service" built on top of Postgres. It gave
  this project, without hand-rolling a server:
  - **Postgres database** — `profiles` (one row per player: display name,
    persistent score, streak, last-active timestamp) and
    `daily_test_results` (Daily Challenge submissions, feeding the
    leaderboard).
  - **Auth** — email/password sign-up and native Google Sign-In, session
    tokens, password-reset flows — all handled by Supabase rather than
    built from scratch.
  - **Row-Level Security (RLS)** — Postgres-level rules that mean even if a
    malicious client tried to query another player's private row directly,
    the database itself refuses. This is what makes it *safe* for the
    Flutter app to talk to the database somewhat directly using a public
    "anon key" (see §4's security note).
  - **Edge Functions** — small server-side TypeScript functions for the two
    things that must *not* run on the client: deleting a user's
    authentication record (`delete-own-account` needs an elevated
    "service-role" credential a client app can never safely hold) and a
    scheduled cleanup job for long-inactive accounts (`delete-inactive-users`,
    triggered by a cron schedule inside Supabase, not by the app).
  - **Supabase CLI** — the command-line tool used to `supabase functions
    deploy <name>` (push an Edge Function live) and `supabase functions
    list` (confirm what's actually deployed and active).

### Monetization
- **`google_mobile_ads`** (AdMob's official Flutter package) — shows banner,
  interstitial, and rewarded ads. Currently wired up with Google's published
  **TEST** ad unit IDs (safe placeholder IDs anyone can use during
  development without a real AdMob account) — swapping these for real ones
  is on `DEPLOYMENT_CHECKLIST.md`.
- **UMP (User Messaging Platform) consent SDK** — bundled inside
  `google_mobile_ads`; shows the legally-required consent dialog to
  EEA/UK users before any personalized ad can be shown.

### Auth
- **`google_sign_in`** — native Google Sign-In via Android's Credential
  Manager, the modern (non-deprecated) way to offer "Sign in with Google" on
  Android.

### State & storage (client-side)
- **`provider`** — a lightweight state-management package; `GameController`
  (the object holding "what puzzle is showing, what's the current score,
  how much time is left") is exposed to the widget tree via `provider` so
  any screen can react to it changing without manually wiring callbacks
  everywhere.
- **`shared_preferences`** — simple persistent key-value storage on the
  device itself (separate from Supabase) — used for things like "has this
  player already seen the rules dialog" and a locally-cached copy of stats,
  so the Home screen has *something* to show instantly even before a network
  round-trip to Supabase completes.
- **`uuid`** — generates the unique IDs `Puzzle` objects carry.

### Quality & testing
- **`flutter_test`** — Flutter's built-in testing framework. This project's
  359 tests are a mix of:
  - **Unit tests** — pure logic, no UI (e.g. does the streak calculator
    handle a UTC day boundary correctly).
  - **Widget tests** — pump a widget into a simulated environment and assert
    on what's rendered/tappable, without needing a real device or emulator.
  - **Fuzz tests** — e.g. every puzzle generator runs 500 times per
    difficulty tier with random inputs, and every single result is
    independently re-verified as correct (not just "did it crash").
- **`flutter analyze`** (+ `flutter_lints`) — static analysis: catches unused
  imports, type errors, and a large set of Dart/Flutter style and
  correctness lints, without running any code.
- **Claude Artifact tool** — used to publish the public, no-install-required
  account-deletion instructions page Google Play requires — a small piece
  of infrastructure that lives *outside* the app itself but is a real,
  required part of shipping it.

---

## 4. Concepts and judgment calls a lead developer needs from this project

These are the "why," not the "what" — the parts a new lead would otherwise
have to rediscover the hard way.

**Determinism is the whole trick behind Daily Challenge fairness.** Every
puzzle generator takes an `RngService` instance instead of calling
`dart:math`'s `Random` directly. For Daily Challenge, that `RngService` is
seeded from the date string, so *every player's device*, independently,
generates the exact same sequence of questions on the same calendar day —
with no server round-trip needed to hand out "today's questions." This only
works because every generator is disciplined about using the passed-in `rng`
for every random decision, never a second, independent random source.

**Row-Level Security, not client-side trust, is what makes the anon key
safe.** The Supabase "anon key" embedded in the app is public — anyone can
extract it from the compiled APK. That's fine *only* because Postgres RLS
policies enforce "a client can only read/write its own `profiles` row"
directly in the database, not in app code that could be bypassed. Any new
table added to this schema needs its own RLS policy from day one, not as an
afterthought.

**Never let the client hold a service-role key.** The two Edge Functions
exist specifically because deleting a user's `auth.users` row and running
the scheduled inactivity cleanup both need Supabase's elevated "service
role" credential — a credential that must never ship inside the app. Server-
side functions are the only place that key is ever used.

**Best-effort vs. must-succeed is a deliberate, consistent rule in this
codebase.** Ad SDK calls, most background stat syncs, etc. are wrapped so a
failure never crashes or blocks the player (a missing ad is a shrug, not a
bug). Account deletion is the deliberate exception — its failure *must*
surface to the player rather than fail silently, since silently "succeeding"
at nothing would leave someone believing their data is gone when it isn't.
Any new feature should make this call explicitly, not by default.

**Difficulty is table-driven, not hardcoded per-generator.**
`difficulty_curve.dart` is the single place tier-to-parameter mappings live
(number ranges, time limits, family-tree hop depth, etc.) — new generators
should read from it rather than inventing their own ad hoc tier logic,
except where a topic's own difficulty knob genuinely doesn't fit the shared
schema (documented case by case in `ROADMAP_PHASE2.md`).

**Testing discipline is what makes fast iteration safe.** The
`flutter analyze && flutter test` gate ran after nearly every single change
in this project's history — not just before a release. This is what allowed
large refactors (like this session's account-deletion UI redesign) to be
done confidently in minutes rather than hours of manual re-testing.

**Documentation was treated as a living spec, not a changelog.**
`ARCHITECTURE.md` and `ROADMAP_PHASE2.md` were updated *as part of* each
feature's own commit, describing not just what was built but *why* — e.g.
why account deletion needs an explicit `popUntil` call, or why a triangle's
three sides are generated close together around a random base instead of
independently. A new engineer should be able to read these two files and
understand the reasoning behind the code, not just its current shape.

**Git hygiene**: every commit message explains the *why*, not just the
*what* (see any commit in `git log` on this repo); commits are verified
against `origin/main` before every push (`git fetch && git merge-base
--is-ancestor origin/main HEAD`) to avoid silently overwriting remote work;
and attribution trailers (`Co-Authored-By:`) are kept consistent.

---

## 5. How to actually extend this project

- **Add a new puzzle topic**: add an entry to `PuzzleType` in
  `lib/models/puzzle.dart`, write a generator following the
  `abstract final class` + static `generate({required tier, required rng})`
  convention (copy `lib/services/ratio_generator.dart` as the simplest
  recent template), wire it into `puzzle_generator.dart`'s dispatcher
  `switch`, and add a case to `test/services/puzzle_generator_test.dart`'s
  `_independentlyVerify` switch — the shared 500-generation fuzz test
  covers the rest for free.
- **Add a new screen**: follow the existing pattern — a `StatefulWidget` in
  `lib/screens/`, pushed via `Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => YourScreen()))`, with a matching `test/screens/` widget
  test.
- **Run everything locally**: `flutter analyze` then `flutter test` —
  always both, always before considering a change finished.
- **Deploy a changed Edge Function**: `supabase functions deploy
  <function-name>` via the Supabase CLI, then `supabase functions list` to
  confirm it shows `ACTIVE`.
- **Before any release build**: work through `DEPLOYMENT_CHECKLIST.md` top
  to bottom.

---

## 6. Glossary

- **Widget** — Flutter's basic building block; everything on screen (and a
  lot that isn't, like animations and gesture detectors) is a widget.
- **State management** — how a Flutter app tracks "data that can change and
  needs the UI to update when it does." This project uses `provider`.
- **RLS (Row-Level Security)** — Postgres feature restricting which rows a
  given database user/session can see or modify, enforced by the database
  itself.
- **Edge Function** — a small server-side function (here, on Supabase's
  Deno-based runtime) that runs outside the client app, for anything that
  needs elevated trust.
- **Seed / seeded RNG** — a starting value that makes a "random" number
  generator produce the exact same sequence every time it's given that same
  seed — the mechanism behind Daily Challenge fairness.
- **Fuzz test** — a test that runs the same logic many times (here, 500x)
  with varied random inputs, checking an invariant holds every time, rather
  than testing one fixed example.
- **Lint** — a static-analysis warning about code style or a likely mistake,
  short of an outright compile error.
