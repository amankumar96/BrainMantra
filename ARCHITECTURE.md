# MathBlitz — Technical Architecture
**Purpose of this document:** This is the source-of-truth spec for building MathBlitz using Claude Code. Every module below has a defined contract (inputs/outputs), a file location, and a test that must pass before moving to the next step. Build strictly in the order given — each phase depends only on phases before it, never after.

**Stack:** Flutter (Dart), local-first with optional Firebase backend, AdMob for ads.

---

## 0. Ground Rules for Claude Code

1. Work **one numbered step at a time**. Do not start step N+1 until step N's "Definition of Done" is met.
2. Every service/model file gets a matching test file in `test/`, written in the same step as the code, not later.
3. Run `flutter test` after every step and paste/confirm the output before proceeding.
4. Do not touch UI (`screens/`, `widgets/`) until Phase 2 is fully green. Logic must be provably correct before it's wrapped in a UI.
5. Keep each file under ~200 lines. If a service grows past that, split it.
6. No hardcoded puzzle answers anywhere — all answers must be computed at generation time.

---

## 1. Project Structure

```
math_blitz/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── puzzle.dart
│   │   ├── game_session.dart
│   │   └── player_stats.dart
│   ├── services/
│   │   ├── rng_service.dart
│   │   ├── puzzle_generator.dart                 (dispatcher + family-tree question construction)
│   │   ├── puzzle_generator_basic_math.dart      (arithmetic, trueFalse, missingNumber)
│   │   ├── puzzle_generator_odd_one_out.dart
│   │   ├── puzzle_generator_sequence_target.dart (sequence, targetNumber)
│   │   ├── family_tree.dart                (shared Person/Sex/FamilyTree data shape)
│   │   ├── family_tree_generator.dart      (Phase 1, reasoning branch)
│   │   ├── relationship_resolver.dart      (Phase 1, reasoning branch)
│   │   ├── shape_reasoning_generator.dart  (Phase 1, reasoning branch)
│   │   ├── rng_utils.dart                  (shuffle/deterministicId/MC-option helpers)
│   │   ├── expression_evaluator.dart
│   │   ├── difficulty_curve.dart
│   │   ├── storage_service.dart
│   │   └── ads_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── game_screen.dart
│   │   ├── results_screen.dart
│   │   ├── leaderboard_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   ├── timer_bar.dart
│   │   ├── answer_button.dart
│   │   ├── combo_indicator.dart
│   │   └── feedback_overlay.dart           (Phase 2, balloon burst / red cross)
│   └── utils/
│       └── constants.dart
├── test/
│   ├── services/
│   │   ├── rng_service_test.dart
│   │   ├── expression_evaluator_test.dart
│   │   ├── difficulty_curve_test.dart
│   │   ├── relationship_resolver_test.dart
│   │   ├── family_tree_generator_test.dart
│   │   ├── shape_reasoning_generator_test.dart
│   │   ├── puzzle_generator_test.dart
│   │   └── storage_service_test.dart
│   └── models/
│       ├── puzzle_test.dart
│       ├── game_session_test.dart
│       └── player_stats_test.dart
├── assets/
│   ├── sounds/
│   └── icons/
└── pubspec.yaml
```

---

## 2. Data Models (build first — Phase 0)

### `Puzzle` (`lib/models/puzzle.dart`)
```
enum PuzzleCategory { mathTest, reasoningTest }

enum PuzzleType {
  // mathTest
  arithmetic, trueFalse, missingNumber, oddOneOut, sequence, targetNumber,
  // reasoningTest — open for more values later (seating arrangement, syllogism, pattern...)
  familyTree, shapeIdentification,
}

class Puzzle {
  String id;                  // uuid, generated at creation
  PuzzleCategory category;    // mathTest | reasoningTest
  PuzzleType type;            // see enum above
  String questionText;        // e.g. "7 × 8 = ?" or "Which shape has 5 sides?"
  List<String> options;       // for multiple choice types; empty for free-input types
  dynamic correctAnswer;      // int, bool, or String depending on type
  int difficultyTier;         // 1 = easy ... 4 = insane
  int timeLimitSeconds;
}
```
**Definition of Done:** model compiles, has `toJson`/`fromJson`, and a test verifying serialization round-trips correctly through a real `jsonEncode`/`jsonDecode` boundary (not just `fromJson(toJson())` in memory — that would miss `correctAnswer` type-preservation bugs).

> **Amendment (post-initial-draft):** the app now covers two test categories, not just math. `Puzzle.category` was added so math and reasoning questions are cleanly separable for stats and difficulty curves, while `type` stays a single flat enum (simpler JSON, one `byName` lookup) namespaced by category. Reasoning starts with `familyTree` (relationship questions, scaling **direct → in-law → multi-hop** by difficulty tier) and `shapeIdentification` (property-based questions, e.g. "which shape has 5 sides?"), and is deliberately left open for more reasoning sub-types later (seating arrangement, syllogisms, patterns, ...) without any further structural change to `Puzzle`. See `lib/models/puzzle.dart` for the implementation.

### `GameSession` (`lib/models/game_session.dart`)
```
class GameSession {
  DateTime startedAt;
  int score;
  int comboMultiplier;
  int livesRemaining;
  List<Puzzle> puzzlesAnswered;
  List<bool> correctness;      // parallel array to puzzlesAnswered
  bool isDailyChallenge;
  String? seedUsed;             // only set if isDailyChallenge
}
```

### `PlayerStats` (`lib/models/player_stats.dart`)
```
class PlayerStats {
  int highScore;
  int currentStreakDays;
  DateTime? lastPlayedDate;
  int totalCoins;
  Map<int, int> bestScoreByTier;
}
```

**Phase 0 exit test:** `flutter test test/models/` — all model serialization tests green. ✅ Done — 24 tests passing, `flutter analyze` clean.

---

## 3. Phase 1 — Core Logic (no UI, fully unit-testable)

This is the most important phase. Build and test each service **in this exact order**, since each depends on the previous.

### Step 1.1 — `rng_service.dart`
**Contract:**
- `RngService.free()` — returns an RNG seeded from system entropy (`Random.secure()` or `Random()`).
- `RngService.seeded(String seed)` — returns a deterministic RNG (Mulberry32 or similar PRNG) derived from a hashed string seed.
- Both expose `.nextInt(min, max)` and `.nextBool()`.

**Test cases (`rng_service_test.dart`):**
- Same seed → same sequence of 20 calls, every time.
- Different seeds → sequences diverge (no false collisions in a 20-call sample).
- `free()` calls do not throw and stay within requested bounds across 1000 iterations.

**Definition of Done:** all 3 tests pass.

---

### Step 1.2 — `expression_evaluator.dart`
**Contract:**
- `evaluate(String expression) → num` — safely evaluates a simple arithmetic string (`+ - × ÷`, parentheses, no external packages if avoidable, or use a minimal well-known package like `math_expressions`).
- Must throw a typed `EvaluationException` on divide-by-zero or malformed input — never silently return wrong values.

**Test cases:**
- `"3 + 4 × 2"` → `11` (operator precedence respected).
- `"(3 + 4) × 2"` → `14`.
- `"5 ÷ 0"` → throws `EvaluationException`.
- Malformed string → throws, does not crash.

**Definition of Done:** all pass; this module is later reused by `puzzle_generator.dart` for the "Target Number" mode to self-validate generated answers.

---

### Step 1.3 — `difficulty_curve.dart`
**Contract:**
- `DifficultyCurve.tierForScore(int score) → int` (1–4).
- `DifficultyCurve.paramsForTier(int tier) → DifficultyParams` (returns `{minOperand, maxOperand, allowedOperators, timeLimitSeconds}` for math; and reasoning-specific params — family-tree hop depth per tier, shape complexity/side-count range per tier).

**Test cases:**
- Score 0 → tier 1. Score just under next threshold → same tier. Score at threshold → tier increments.
- Tier 4 params have a strictly smaller `timeLimitSeconds` and wider operand range than tier 1.
- Family-tree hop depth increases monotonically with tier (tier 1: direct relations only; tier 2: + in-law; tier 3–4: + multi-hop/cousins).

**Definition of Done:** thresholds match the design doc's Easy–Insane table; tests pass.

---

### Step 1.4 — `puzzle_generator.dart` (+ reasoning-branch services)
**Contract:**
- `PuzzleGenerator.generate({required int tier, required PuzzleType type, required Random rng}) → Puzzle`.
- **Math branch:** internally uses `rng_service` output + `difficulty_curve` params, and for `targetNumber` type, uses `expression_evaluator` to confirm the generated answer is correct before returning.
- **Reasoning branch:**
  - `family_tree_generator.dart` builds a random kinship graph (depth scaled by tier per `difficulty_curve`), and `relationship_resolver.dart` walks the graph to compute the correct relationship name — the reasoning-category counterpart to `expression_evaluator`, used both to generate the question and to self-validate the answer (no hardcoded family-tree Q&A pairs).
  - `shape_reasoning_generator.dart` produces property-based questions (side counts, shape names) from a small shape→property table — a geometric fact like "a pentagon has 5 sides" is domain knowledge used to *derive* the answer, not a hardcoded puzzle answer.
- Must guarantee: no duplicate options in multiple-choice puzzles, correct answer always present in `options` for MC types, and answer types match `PuzzleType`.

**Test cases (this is the module that needs the most coverage):**
- Generate 500 puzzles per type at each tier — zero exceptions, zero malformed puzzles (applies to both math and reasoning branches).
- For each generated puzzle, independently re-derive the correct answer and assert it matches `puzzle.correctAnswer` (this catches silent logic bugs).
- Same seeded RNG in → identical puzzle out, called twice (determinism check for daily challenge use case).
- Anti-repeat: generating 10 puzzles in a row from one seeded RNG produces no exact duplicate `questionText`.

**Definition of Done:** all pass, including the 500-iteration fuzz tests for every type in both categories. **Do not proceed to Phase 2 until this step is rock solid — it's the foundation everything else trusts.**

---

### Step 1.5 — `storage_service.dart`
**Contract:**
- Wraps `shared_preferences`.
- `saveStats(PlayerStats)`, `loadStats() → PlayerStats`, `saveSession(GameSession)`, `clearAll()`.
- Must handle "no data yet" gracefully (return a default `PlayerStats` instead of throwing).

**Test cases:**
- Save then load → round-trips exactly.
- Load with nothing saved yet → returns defaults, no exception.

**Definition of Done:** tests pass using `shared_preferences`' mock/in-memory implementation for tests.

---

**Phase 1 exit criteria (hard gate):** `flutter test` shows 100% pass across all of `test/services/` and `test/models/`. Do not write a single widget until this is true. ✅ Done — 148 tests passing (24 models + 124 services, including the 500×type×tier fuzz suite for `puzzle_generator`), `flutter analyze` clean.

---

## 4. Phase 2 — Playable UI + Accounts + Ranking ✅ Built

> **Amendment:** Phase 2's scope grew substantially partway through — from "just the offline screens" to also include negative-marking scoring, a 30-day-active leaderboard, and real accounts (Supabase, replacing the originally-sketched Firebase in what was Phase 5 — see that section below, now superseded and folded in here). The subsections below describe what was actually built, not the original lighter sketch.

Built in two internally-gated parts: **Part A** (offline gameplay — screens/widgets/controller, no network) then **Part B** (Supabase accounts + leaderboard).

### Part A — offline gameplay
- **Scoring redesign:** lives/combo replaced entirely by a fixed-length marks test — `+4` correct, `-2` wrong, `0` if the timer runs out unanswered (skipping is free; guessing wrong is not). `totalQuestions` defaults to 10 (`TUNABLE`, `lib/controllers/game_controller.dart`).
- **Timing redesign:** `difficulty_curve.dart`'s time limits moved from an 8–20 *second* fast-blitz range to a 2–30 *minute* exam-pacing range (tier1=2min … tier4=30min, `TUNABLE`) — and the difficulty relationship flipped: harder now means *more* time, not less.
- **Two-step answering:** tapping an option only selects it (`answer_button.dart`'s `selected` state); a separate `submit_button.dart` locks it in — "only 1 attempt before Submit."
- `timer_bar.dart` — live `MM:SS` countdown + progress bar, `AnimationController`-driven, keyed per `puzzle.id` for an automatic per-question reset.
- `marks_indicator.dart` — "Question N of TOTAL · running marks" readout, replacing the old combo/lives indicator.
- `feedback_overlay.dart` — balloon-burst (correct) / red-cross (wrong) / a plain non-punitive icon (skipped, since no marks were lost) — still fully custom-built, no new pub dependency.
- `rules_dialog.dart` — the scoring/timing/submit rules, shown automatically once and reachable anytime via an info icon (item 6 of the product requirements).
- `lib/models/test_session.dart` — a small **additive** model (`AnswerOutcome` enum + `TestSession` wrapping `GameSession`) so 3-outcome marks scoring is representable without changing `GameSession`'s own tested shape.
- `home_screen.dart` / `game_screen.dart` / `results_screen.dart` wire all of the above together; state managed via `provider` (`ChangeNotifierProvider` + `GameController`).
- **Part A gate:** 201 automated tests passing, `flutter analyze` clean, app boots cleanly (verified via `flutter run -d chrome`).

### Part B — Supabase accounts + ranking
- **Player identity:** full sign-up required (`sign_up_screen.dart`/`login_screen.dart`) — email/password (email confirmation disabled per product decision, so sign-up logs in immediately) plus Google sign-in (`AuthService.signInWithGoogle`, web-ready; Android/iOS need their own URL-scheme registration before it works there). Sessions persist automatically (`supabase_flutter`'s default), so a signed-up player stays logged in until they explicitly sign out.
- **Schema** (run directly in the Supabase SQL Editor, not tracked as a repo file): `profiles` (id/display_name, readable by everyone, writable only by its owner), `daily_test_results` (one row per player per UTC day, unique on `(user_id, test_date)`, **readable by everyone, writable only by its owner** — an early version mistakenly used one blanket RLS policy for both read and write, which would have made every player only ever see their own row on the leaderboard; fixed to separate select/insert/update policies, mirroring `profiles`), and a `leaderboard_last_30_days` view (sum of marks per player across submissions in the last 30 days — "active" simply means "has ≥1 row in that window" via the join).
- `leaderboard_service.dart` — `submitDailyResult` (upserts today's row) and `fetchTopRankings` (reads the ranked view).
- **Only Daily Challenge results are ranked** — `Play` uses freely-random questions and isn't a fair, comparable test across players the way a shared-seed Daily Challenge is; both modes still save locally regardless.
- `leaderboard_screen.dart` — ranked list, current player's row highlighted.
- **Part B gate:** live REST check against the real project confirms the schema/RLS are reachable end-to-end; a full sign-up → Daily Challenge → leaderboard playthrough is the final manual check.

**Phase 2 exit criteria:** a human can sign up, see the rules once, play a full test (both Play and Daily Challenge, both categories) with no crashes, see a Daily Challenge result appear correctly ranked on the leaderboard, and have `PlayerStats` persist across app restarts.

### 4a. Gameplay redesign amendment (post-Phase-2) — ✅ Built and deployed

Four changes on top of the above, **scoped to "Play" only** — Daily Challenge is untouched:
1. **Play is now never-ending.** `GameController.totalQuestions` is `int?` (`null` = no cap). Difficulty still climbs, but there's no fixed finish line.
2. **Score is persistent per-account**, not per-session. `GameController.startingScore` resumes from `profiles.current_score` (fetched by `home_screen.dart` before Play starts); an **End** button (`game_screen.dart`'s AppBar, Play only) stops the session, shows the cumulative "score so far" on `results_screen.dart`, and persists it back. `AuthService.touchLastActive()` stamps `profiles.last_active_at` at the end of every session (either mode) — the field the 30-day deletion job checks.
3. **Difficulty tier is randomized**, not a single deterministic lookup: `DifficultyCurve.randomTierForScore(score, rng)` picks from a score-banded weighted set (score<30 → tiers 1-2; 30-300 → tiers 2-4; ≥300 → tiers 1-4 weighted toward 3-4). Used by both modes.
4. **Theme**: light blue + silver (`AppColors.background`/`silver`, `main.dart`'s new `ThemeData`).

**Deployed:** `current_score`/`last_active_at` columns added, FK cascades fixed, `supabase/functions/delete-inactive-users` deployed via the Supabase CLI (installed to `C:\src\supabase-cli`, no Node/npm needed — same "no winget package, get the standalone binary" pattern as Flutter's own install), scheduled via `pg_cron`/`pg_net` + two Vault secrets (`project_url`, `publishable_key`) at `0 3 * * *` (3am UTC daily, job `delete-inactive-users-daily`).

**Manual gates — both passed:**
1. Play → End → resumed from the same score on the next Play. ✅
2. End-to-end deletion proof: created a disposable test account, backdated its `profiles.last_active_at` 31 days, invoked the function by hand — it found exactly that one account (`candidateCount: 1`) and deleted it; confirmed both the `profiles` row and the `auth.users` row are gone (`0 remaining` for both). ✅

**Found and fixed along the way:** the Supabase project's Email auth provider was unexpectedly fully disabled (not just "Confirm email" — the whole provider), discovered when the test signup failed with `email_provider_disabled`. Re-enabled.

**Follow-up resolved — "Confirm email" decision:** kept **ON**. Since email/password sign-up now genuinely requires clicking a confirmation link, the auth UX was reworked to steer players toward Google (which never needs confirmation) as the primary path, with email/password as an explicit secondary option:
- `login_screen.dart` / `sign_up_screen.dart`: "Continue with Google" is now a prominent `FilledButton` at the top of the screen; the email/password form sits below an "or ..." divider, with a smaller `OutlinedButton` submit and a note that a confirmation email will be sent.
- `AuthService.signUp` now returns a `SignUpResult` (`signedIn` or `confirmationEmailSent`) instead of assuming an immediate session. `sign_up_screen.dart` switches to a dedicated "check your email" view when confirmation is pending, rather than silently doing nothing or throwing. The display name typed at sign-up is carried in Supabase user metadata (`data: {'display_name': ...}`) so `ensureProfileExists` — which only actually runs once a session exists, i.e. after the link is clicked, via the `signedIn` listener in `main.dart` — still picks up the right name.
- `login_screen.dart` catches `AuthException` for an unconfirmed account (`email_not_confirmed`) and shows a friendly "click the confirmation link we emailed you" message instead of Supabase's raw error text.

### 4b. Daily Challenge redesign — no longer an isolated score

Daily Challenge stopped being a separate, isolated tally and became a bonus round layered on top of the one persistent Play score:
1. **Tier 3+ only.** `DifficultyCurve.randomHighTier(rng)` (tier 3 or 4, evenly weighted) replaces `randomTierForScore` for Daily Challenge specifically — score-independent, always hard. `GameController._loadNextPuzzle` branches on `isDailyChallenge` to pick between the two.
2. **Flat +10/no-deduction scoring**, mode-dependent in `GameController._score`: Daily Challenge is +10 correct / 0 wrong / 0 skipped, vs. Play's existing +4/-2/0.
3. **Earned marks now add onto the persistent score**, not just the leaderboard. `game_screen.dart`'s `_persistAndShowResults`: Daily Challenge still submits to `daily_test_results` (leaderboard unchanged), but now also fetches the player's current `profiles.current_score`, adds this session's earned marks, and persists that sum back — the same field Play resumes from. `results_screen.dart`'s headline number is that unified total for both modes now, with a small "+N from today's Daily Challenge" line shown only for Daily Challenge.
4. **Leaderboard**: added a "N players ranked" header row to `leaderboard_screen.dart` (was previously answerable only per-row via "N test(s) taken", no participant count anywhere on screen).

**Found and fixed along the way (pre-existing bugs, not introduced by this change):**
- `game_screen.dart` was persisting `testSession.totalMarks` (this session's delta only) to `profiles.current_score` for Play mode — not `testSession.session.score` (the true cumulative figure). This silently discarded `startingScore` on every single Play session end, in production (not caught by any test, since the Supabase call is wrapped in try/catch and swallowed in the test environment where Supabase isn't initialized). Fixed.
- The local "new high score" check compared `testSession.totalMarks` (session-local delta) against `PlayerStats.highScore` instead of the true cumulative score — meaning the Home screen's "High Score" was tracking the wrong quantity. Fixed to compare/store the same cumulative `updatedScore` used for persistence.

---

## 5. Phase 3 — Daily Challenge & Meta Layer

- Wire `RngService.seeded(dateString)` into `game_screen` when `isDailyChallenge = true`.
- **Test:** two separate app installs (or two test runs) on the same date produce an identical puzzle sequence — this is the critical correctness test for leaderboard fairness. Write an automated test that generates a full daily sequence twice from the same date-seed and asserts equality.
- Add streak tracking (`currentStreakDays` increments if `lastPlayedDate` was yesterday, resets if gap > 1 day).
- **Test:** streak logic unit test with mocked dates (yesterday → increments; 3 days ago → resets to 1; today already played → unchanged).

**Phase 3 exit criteria:** daily-seed determinism test passes; streak logic tests pass.

---

## 6. Phase 4 — Ads Integration (`ads_service.dart`)

- Wraps `google_mobile_ads`: `loadRewarded()`, `showRewarded(onReward)`, `loadInterstitial()`, `showInterstitialIfDue()`, `bannerAdWidget()`.
- Use **AdMob test ad unit IDs** during this entire phase — never real ad unit IDs until final release build.
- **Manual test checklist:**
  - [ ] Rewarded ad shown only when player opts in (revive/double-coins button), never auto-played.
  - [ ] Interstitial shows at most once per 3–4 round-ends (verify counter logic with a unit test on the "due" calculation, independent of the actual ad SDK call).
  - [ ] Banner only appears on home/menu, never during active gameplay countdown.

**Phase 4 exit criteria:** all placements verified with test ads; `showInterstitialIfDue()` frequency-cap logic has a passing unit test.

---

## 7. Phase 5 — Optional Firebase Leaderboard — **Superseded, folded into Phase 2**

This phase's original idea (a leaderboard, with server-side anti-cheat) was pulled forward into Phase 2 Part B and built on Supabase instead of Firebase — see that section above for what actually exists. One item from this original sketch is **not yet done** and remains real future work: **server-side score validation** (rejecting a submitted score that exceeds the max theoretically possible for the questions answered). Right now `LeaderboardService.submitDailyResult` trusts whatever `totalMarks` the client computed — a Postgres check constraint or a Supabase Edge Function validating `marks` against `questions_total * 4` (the max possible) before accepting a write would close this gap, matching this section's original anti-spoofing test intent.

---

## 8. Phase 6 — Polish & Store Prep

- Sounds, animations, app icon, screenshots, privacy policy page, Data Safety form.
- Optional: render actual shape drawings for `shapeIdentification` questions (vs. pure text/options) — a visual upgrade, not required for the puzzle to function.
- No new core logic here — purely asset/config work. Nothing to unit test; use a manual pre-launch checklist instead.

---

## 9. Master Checklist (give this to Claude Code as the running task list)

- [x] Phase 0: Models + serialization tests (24 tests passing, `flutter analyze` clean)
- [x] Step 1.1: rng_service + tests
- [x] Step 1.2: expression_evaluator + tests
- [x] Step 1.3: difficulty_curve + tests
- [x] Step 1.4: puzzle_generator (math + reasoning branches) + fuzz tests (500 iterations/type/tier)
- [x] Step 1.5: storage_service + tests
- [x] **Gate: `flutter test` 100% green before any UI work** — 148 tests passing, `flutter analyze` clean
- [x] Phase 2 Part A: offline gameplay (marks scoring, 2-30min timers, select-then-submit, all screens/widgets) — 201 tests passing
- [x] Phase 2 Part B: Supabase accounts (email + Google) + daily-challenge leaderboard, schema verified live
- [ ] **Gate: full manual sign-up → Daily Challenge → leaderboard playthrough + restart-persistence check**
- [x] Gameplay redesign: infinite Play + persistent score + End button + randomized tiers + light blue/silver theme (218 tests passing) — see §4a
- [x] Gameplay redesign: schema SQL run, `delete-inactive-users` deployed, cron scheduled (§4a)
- [x] **Gate: Play → End → resume-same-score check; manually-backdated-account deletion check** — both passed
- [x] Follow-up: "Confirm email" kept ON by decision — Google steered as primary sign-up/login path, "check your email" state built into `sign_up_screen.dart` (see §4a)
- [x] Daily Challenge redesign: tier 3+ only, +10/no-deduction scoring, earned marks now add onto the persistent Play score instead of staying isolated (225 tests passing) — see §4b
- [ ] Step 3: streak logic (daily-seed determinism already exists via `GameController`'s date-seeded RNG, reused from what was planned here)
- [ ] Step 4: ads_service with test ad units + frequency-cap test
- [ ] Server-side score validation on `daily_test_results` writes (anti-cheat gap noted in the superseded Phase 5 section above)
- [ ] Step 6: polish + store assets
- [ ] Submit to Play Console (internal → closed → production)

---

## 10. How to Hand This to Claude Code

Give Claude Code this file plus one instruction per session, e.g.:

> "Read ARCHITECTURE.md. We're on Step 1.1 — build rng_service.dart exactly to the contract and write the tests described. Do not proceed past this step until all tests pass."

This keeps each Claude Code session scoped to one gated, independently verifiable unit of work.
