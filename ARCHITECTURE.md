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
│   │   ├── puzzle_generator.dart
│   │   ├── family_tree_generator.dart      (Phase 1, reasoning branch)
│   │   ├── relationship_resolver.dart      (Phase 1, reasoning branch)
│   │   ├── shape_reasoning_generator.dart  (Phase 1, reasoning branch)
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
│   │   ├── puzzle_generator_test.dart
│   │   ├── expression_evaluator_test.dart
│   │   ├── difficulty_curve_test.dart
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

**Phase 1 exit criteria (hard gate):** `flutter test` shows 100% pass across all of `test/services/` and `test/models/`. Do not write a single widget until this is true.

---

## 4. Phase 2 — Playable UI (manual test checklist, not just automated)

Build screens in this order; each has both an automated widget test where practical and a manual checklist, since gameplay feel needs human verification.

### Step 2.1 — `home_screen.dart`
- Shows high score, streak, "Play" and "Daily Challenge" buttons.
- **Manual test:** launching app with no prior data shows 0/0 gracefully; tapping Play navigates to `game_screen`.

### Step 2.2 — `game_screen.dart`
- Pulls a `Puzzle` from `PuzzleGenerator` (math or reasoning category), renders question + 4-option MCQ / free-input, countdown via `timer_bar.dart`, tracks lives/combo via `GameSession`.
- On answer selection, triggers `feedback_overlay.dart`: a custom-built balloon-burst animation on correct, a custom-built red-cross animation on wrong (no new pub dependency).
- **Manual test checklist:**
  - [ ] Timer counts down and auto-submits wrong on expiry.
  - [ ] Correct answer → balloon-burst feedback, increments score + combo; wrong answer → red-cross feedback, decrements lives and resets combo.
  - [ ] 3 wrong answers → navigates to `results_screen`.
  - [ ] Difficulty visibly increases as score crosses tier thresholds (verify against `difficulty_curve` params), for both math and reasoning categories.

### Step 2.3 — `results_screen.dart`
- Shows final score, best score comparison, "Play Again" / "Watch ad to revive" (revive logic wired later in Phase 4) / share.
- **Manual test:** score correctly persisted via `storage_service` after each session; high score updates only when beaten.

**Phase 2 exit criteria:** a human can play a full game start-to-finish (both categories) with no crashes, and `PlayerStats` persists correctly across app restarts (kill and relaunch the app to verify).

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

## 7. Phase 5 — Optional Firebase Leaderboard

Only start this after Phase 4 is done and the game is fun to play standalone.
- Firestore collection `leaderboard_daily/{date}/scores/{uid}`.
- Cloud Function (or client-side write with security rules) to prevent score spoofing — validate score against max-possible-score-per-tier server-side before accepting a write.
- **Test:** attempt to submit an impossible score (e.g. exceeds max theoretical score for puzzles-answered count) → rejected by security rule/function.

---

## 8. Phase 6 — Polish & Store Prep

- Sounds, animations, app icon, screenshots, privacy policy page, Data Safety form.
- Optional: render actual shape drawings for `shapeIdentification` questions (vs. pure text/options) — a visual upgrade, not required for the puzzle to function.
- No new core logic here — purely asset/config work. Nothing to unit test; use a manual pre-launch checklist instead.

---

## 9. Master Checklist (give this to Claude Code as the running task list)

- [x] Phase 0: Models + serialization tests (24 tests passing, `flutter analyze` clean)
- [ ] Step 1.1: rng_service + tests
- [ ] Step 1.2: expression_evaluator + tests
- [ ] Step 1.3: difficulty_curve + tests
- [ ] Step 1.4: puzzle_generator (math + reasoning branches) + fuzz tests (500 iterations/type/tier)
- [ ] Step 1.5: storage_service + tests
- [ ] **Gate: `flutter test` 100% green before any UI work**
- [ ] Step 2.1: home_screen
- [ ] Step 2.2: game_screen + feedback_overlay (manual checklist above)
- [ ] Step 2.3: results_screen
- [ ] **Gate: full manual playthrough + restart-persistence check**
- [ ] Step 3: daily challenge determinism + streak logic
- [ ] Step 4: ads_service with test ad units + frequency-cap test
- [ ] Step 5 (optional): Firebase leaderboard + anti-cheat validation
- [ ] Step 6: polish + store assets
- [ ] Submit to Play Console (internal → closed → production)

---

## 10. How to Hand This to Claude Code

Give Claude Code this file plus one instruction per session, e.g.:

> "Read ARCHITECTURE.md. We're on Step 1.1 — build rng_service.dart exactly to the contract and write the tests described. Do not proceed past this step until all tests pass."

This keeps each Claude Code session scoped to one gated, independently verifiable unit of work.
