# MathBlitz — Roadmap (All Phases, Plain Language)

Companion to [`02-journey-so-far.md`](./02-journey-so-far.md) (the story of what happened) and [`01-project-file-guide.md`](./01-project-file-guide.md) (what every file is). This one is the forward-looking map: every phase, what it delivers, and how we know it's actually done.

The rule underneath all of it, from `ARCHITECTURE.md`: **each phase is a hard gate.** Nothing in a later phase starts until the current phase's automated tests are 100% green. That's deliberate — it means bugs get caught in the small, boring, invisible layer instead of the big, flashy, hard-to-debug layer.

| Phase | What it delivers | Status |
|---|---|---|
| 0 | Data blueprints | ✅ Done |
| 1 | Core logic ("the brain") | ✅ Done |
| 2 | Playable screens | ⏭️ Next |
| 3 | Daily Challenge + streaks | ⏳ Not started |
| 4 | Ads | ⏳ Not started |
| 5 | Online leaderboard (optional) | ⏳ Not started |
| 6 | Polish + store submission | ⏳ Not started |

---

## Phase 0 — Data blueprints ✅ Done
Defined the *shape* of a question, a game session, and a saved player profile — no behavior, just structure. 3 files, 24 automated checks, all passing.

## Phase 1 — Core logic ✅ Done
Built the actual "brain": the question generator (math + family-tree + shape reasoning), the difficulty system, the arithmetic self-checker, and the save/load system. Zero visuals — everything provable from a terminal. 148 automated checks passing, including a 16,000-question fuzz test on the generator. Caught and fixed 3 real bugs along the way (see the journey doc).

## Phase 2 — Playable screens ⏭️ Next up
Where the app becomes something you can see and tap.

1. **`home_screen`** — title screen: high score, streak, Play / Daily Challenge buttons.
   - Manual check: fresh install shows 0/0 gracefully; Play navigates to the game.
2. **`game_screen`** — the actual gameplay: pulls a real question from Phase 1, shows it with a 4-option layout, a countdown timer, live score/lives/combo, and the balloon-burst (correct) / red-cross (wrong) feedback.
   - Manual check: timer auto-fails on expiry; correct → balloons + score/combo up; wrong → red cross + life lost, combo reset; 3 wrong ends the game; difficulty visibly ramps with score, for both math and reasoning questions.
3. **`results_screen`** — game-over screen: final score, best-score comparison, Play Again.
   - Manual check: score persists; high score updates only when actually beaten.

**Done when:** a full game can be played start-to-finish with no crashes, and stats survive an app restart.

## Phase 3 — Daily Challenge & streaks ⏳
Feeds today's date into the seeded-randomness system from Phase 1 so every player gets an identical daily question set (fair for comparing scores later). Adds day-streak tracking.
- Tests: same date -> same sequence every time; streak math correct for "yesterday" (+1), "3 days ago" (reset to 1), "already played today" (unchanged).

## Phase 4 — Ads ⏳
Real ad placements — rewarded video (revive), occasional interstitial, home-screen banner — built and tested against Google's official *test* ad IDs the entire phase; real ad IDs only go in at final release.
- Manual checks: nothing auto-plays; interstitial capped at roughly once per 3-4 rounds; banner never shows mid-game.

## Phase 5 — Online leaderboard (optional) ⏳
Only tackled once the game is already fun standalone. Compares Daily Challenge scores across players online, with a server-side check that rejects impossible/spoofed scores.

## Phase 6 — Polish & store submission ⏳
No new logic — sound, animation, real app icon, screenshots, privacy policy, optionally drawing actual shapes for shape-ID questions instead of naming them. Ends with Play Store submission (internal -> limited -> public release).
