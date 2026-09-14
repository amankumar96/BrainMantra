# Brain Mantra — Phase 2 Roadmap (Post-Launch Feature Expansion)

**Status context:** Phases 0–6 from `ARCHITECTURE.md` (core logic, playable UI, daily challenge, ads, polish, store submission) are treated as **done**. This document picks up from there. Same rule as before applies: **build in order, gate each step behind a passing test, don't start the next step until the current one is green.**

---

## Phase 7 — Expanded Math Topic Library — ✅ Built (non-diagram topics)

**Goal:** grow beyond arithmetic/pattern puzzles into exam-relevant topics, without changing the core engine — new topics plug into the existing `PuzzleGenerator` contract from Phase 1.

Four non-diagram topics were built as their own generators, each following the `abstract final class` + static `generate({required tier, required rng})` convention (matching `ShapeReasoningGenerator`, the most recently-established reasoning-category pattern) and wired into `PuzzleGenerator`'s dispatcher switch:

| Topic | Generator | Notes |
|---|---|---|
| BODMAS | `lib/services/bodmas_generator.dart` | Builds an expression string, evaluated by the existing `expression_evaluator.dart` — never a hand-rolled precedence check, so the answer is guaranteed correct. |
| Speed/relative speed | `lib/services/speed_distance_generator.dart` | Same-direction subtracts, opposite adds. |
| Profit & Loss | `lib/services/profit_loss_generator.dart` | Cost price + percentage generated first, selling price *derived* — the percentage is always exact, no rounding needed. |
| Simple & Compound Interest | `lib/services/interest_generator.dart` | SI is always an exact integer by construction; CI is rounded to the nearest rupee (this project's numeric `Puzzle.correctAnswer` is always `int`, matching every other generator — see Phase 8's rounding note below). |

**Area/Volume and Triangle** (originally sketched here) were built as part of Phase 8 instead — see below — since they need an actual diagram to be a fair question, not just text.

**Tier scaling**: each new generator keeps its own small tier-to-parameter table *locally* (e.g. `BodmasGenerator._complexityForTier`), the same pattern `puzzle_generator_basic_math.dart`'s `_distractorSpread` already uses, rather than adding new shared fields to `difficulty_curve.dart`'s `MathParams`/`ReasoningParams` — lower risk to the already-heavily-tested shared difficulty infrastructure, and each new topic's knobs don't naturally fit either existing params bucket.

**Hints (new, not in the original sketch — added by product decision):** every new generator populates `Puzzle.hint` with a formula/theorem-name nudge — but **only at tier 3–4**. At tier 1–2, `hint` stays `null`: the format alone is the exercise there, and a hint would just give the answer away. See Phase 8 below for the full hint table.

**Testing**: no dedicated test file per generator (matching the existing convention — `puzzle_generator_basic_math.dart`/`_odd_one_out.dart`/`_sequence_target.dart` don't have their own files either). Every new `PuzzleType` gets 500-generation correctness-fuzz + self-validation, determinism, and hint-gating coverage for free via `test/services/puzzle_generator_test.dart`'s existing per-type loop — each new type just needed a case added to that file's `_independentlyVerify` switch.

**Topic selection UI** (Step 7.3 in the original sketch) — not built. Every new type is simply added to the uniform-random pool `GameController._pickNextType()` already draws from, same as every other type; a "choose topics" toggle remains real future work, not started.

**Phase 7 exit criteria:** met for the four topics above — `flutter test` green, self-validated per-generation.

---

## Phase 8 — Diagram-Based Question Generator — ✅ Built (Stage 1)

**Goal:** questions where the puzzle *is* a picture — a triangle with two angles labeled asking for the third; a rectangle/circle/cylinder asking for area/volume; a plotted coordinate point asking for its distance from the origin; a bar graph asking a reading question.

### Correction to this document's original research
The original draft of this section cited a "geofig" (SymPy-based) library and a "p33" npm package for triangle coordinate math. **Neither exists as a real, published library** — verified by direct search, not found on PyPI, npm, or GitHub under those names. Not a problem: the actual math (below) is standard, well-documented trigonometry needing no library at all.

### How this actually works
1. **The math first, always.** Generate the underlying numeric values (e.g. two triangle angles), then *derive* the diagram's coordinates from them — never generate a picture and a question separately, or they drift out of sync. The third angle is always `180 - a - b`, computed fresh, never a separately-chosen value.
2. **Triangle vertex placement** (`lib/services/angle_finding_generator.dart` builds the numbers; `lib/widgets/diagram_painter.dart` places them): vertex `P0` at the origin, `P1` at `(baseLength, 0)`. By the law of sines, `P0P2`'s length is `baseLength × sin(B) / sin(C)`; `P2 = P0 + length × (cos(A), sin(A))`. Plain `dart:math` trig (`sin`/`cos`/`pi`), no package.
3. **Rendering — `CustomPainter` + `Canvas`, no drawing/charting package.** `lib/widgets/diagram_painter.dart` is one painter switching on `DiagramKind` (triangle/rectangle/circle/cylinder/coordinatePoint/barGraph), each case 20–40 lines: `Canvas.drawPath`/`drawRect`/`drawCircle`/`drawOval`/`drawLine` plus a small `TextPainter`-based label helper. `fl_chart` (a real, well-maintained package) was considered for the bar-graph type specifically and **deliberately not added** — these are static 3–5-bar "read the value" diagrams, not interactive charts, and a hand-rolled painter is simpler while keeping this project's existing zero-drawing-dependency pattern intact.

### Two-stage scope
- **Stage 1 (built) — diagram in the question, text options.** The diagram sits *after* the question text, side-by-side with the options rather than stacked above them — this fits the existing architecture almost for free, since `AnswerButton.label` is already just a `String`.
- **Stage 2 (not built) — diagram-as-answer-option.** Mirror image, rotation, figure series — needs the four *options themselves* to be little rendered diagrams, which `AnswerButton` can't do yet (it only renders a text `label`). Real, contained future scope: a `Puzzle.optionDiagrams` field and a diagram-rendering `AnswerButton` variant. Not started.

### What was actually built (Stage 1)
| Type | `PuzzleType` | Generator | Diagram |
|---|---|---|---|
| Triangle angle-finding | `angleFinding` | `angle_finding_generator.dart` | Triangle, two angles labeled, third marked "?" |
| Rectangle/circle/cylinder area or volume | `areaVolume` | `area_volume_generator.dart` | Labeled shape (one of the three, picked per generation) |
| Coordinate distance from origin | `coordinateDistance` | `coordinate_distance_generator.dart` | Point plotted on a small axis, drawn from a table of Pythagorean triples so the answer is always a clean integer |
| Bar-graph reading | `graphReading` | `graph_reading_generator.dart` | Rendered bar chart, value labels on each bar |

`Puzzle` gained two new optional fields to support this: `diagramData` (a `DiagramData` — `lib/models/diagram_data.dart`, one shared nullable-fields container per `DiagramKind`, serializable, purely additive to `Puzzle.toJson`/`fromJson`/`==`/`hashCode`) and `hint` (a `String?`).

### Layout (your correction to the original sketch)
The diagram does **not** sit above the question — it sits *after* the question text, and *beside* the options rather than stacked above them: question full-width at top, then a `Row` with the options column on the **left** (stretched to a clean shared left/right edge, not just loosely left-aligned) and the diagram on the **right**. This row layout applies only when `puzzle.diagramData != null` — every non-diagram question type keeps the original centered single-column layout untouched (`game_screen.dart`'s `_QuestionAndOptions._buildOptionsOnly` vs. `_buildOptionsWithDiagram`).

### Hints (tier 3-4 only)
| Type | Tier 3-4 hint |
|---|---|
| BODMAS | "Order of operations: Brackets, Orders, Division/Multiplication, Addition/Subtraction" |
| Speed/relative speed | "Same direction: subtract speeds. Opposite: add speeds." |
| Profit & Loss | "Profit/Loss % = (SP − CP or CP − SP) / CP × 100" |
| Simple/Compound Interest | "SI = PRT/100" / "CI = P(1 + r/100)ᵗ − P" |
| Triangle angle-finding | "Angle Sum Property: angles of a triangle add to 180°" |
| Rectangle/circle/cylinder | "Area = length × width" / "Area = πr²" / "Volume = πr²h" |
| Coordinate distance | "Pythagorean Theorem: a² + b² = c²" |
| Bar-graph reading | (none — reading a graph isn't formula-driven) |

### Rounding convention
Every numeric answer stays an `int`, matching every pre-existing generator (`Puzzle.correctAnswer` has always been `int`/`bool`/`String`, never a fraction). Circle/cylinder area-volume and Compound Interest round to the nearest whole unit; distractor spread scales with the answer's own magnitude (`AreaVolumeGenerator._spreadFor`) so a volume in the hundreds doesn't get distractors only 2-3 apart.

### Testing
- Every new `PuzzleType` gets the same 500-generation fuzz/self-validation/determinism/hint-gating coverage described in Phase 7, via `puzzle_generator_test.dart`.
- `coordinateDistance` and `graphReading` are excluded from that shared file's "10 draws, no duplicate questionText" anti-duplicate check — both have a genuine small-possibility-space reason (a handful of Pythagorean triples; a ranking-question phrasing that doesn't name a category in the text), the same rationale `shapeIdentification` was already excluded for. Each gets its own dedicated variety test instead: `test/services/coordinate_distance_generator_test.dart`, `test/services/graph_reading_generator_test.dart`.
- `lib/widgets/diagram_painter.dart`: `test/widgets/diagram_painter_test.dart` — a paints-without-throwing smoke test per `DiagramKind` (including every triangle `unknownAngleIndex` position) plus `shouldRepaint` unit tests.
- `test/screens/game_screen_test.dart`: two end-to-end tests through the real `GameScreen` — a diagram question renders both the `DiagramPainter` and every option, plus its hint; a hinted non-diagram question shows the hint with no diagram present.

**Manual gate — done, on-device.** Real-device review of the on-screen result turned up three issues, all fixed:
- **Hints now sit behind a "Show hint" button**, not shown automatically — a player taps to reveal the formula/theorem name, rather than seeing it the instant a tier 3-4 question loads (which was closer to giving the answer away than a nudge). `_QuestionAndOptions` became a `StatefulWidget` (`_hintRevealed`, reset per question via a `ValueKey(puzzle.id)` on the widget itself, same "fresh state per question" pattern `TimerBar`/`FeedbackOverlay` already use).
- **A Skip button** was added next to Submit (`GameController.skipManually()`, identical scoring to `skipDueToTimeout` — 0 marks, `AnswerOutcome.skipped` — just triggered by the player instead of the clock) — there was previously no way to move past a question without either answering or waiting out the full timer.
- **Diagrams could overflow their box** — a real correctness bug, not just polish: `_paintTriangle` scaled the triangle only against the box's *width*, so a tall/narrow triangle's apex could land above the box entirely (canvas y < 0), overlapping the question text. Fixed by computing the triangle in unit space first and scaling it to fit **both** axes at once (`trianglePoints`, now a top-level pure function in `diagram_painter.dart` specifically so this is unit-testable against extreme angle shapes, not just smoke-tested) — `test/widgets/diagram_painter_test.dart` asserts every vertex stays within bounds across 5 extreme triangle shapes × 3 box sizes (15 cases), including a size close to a real phone's split-column width. `rectangle`/`cylinder`/`coordinatePoint`/`barGraph` all got the same "fit within padding on every axis" treatment, and moved a couple of edge-hugging labels (previously positioned to the right of the shape, which could run off a narrow box) to sit left/below instead. On top of the corrected math, `game_screen.dart` now wraps the diagram in a visible bordered frame + a hard `ClipRect` as a backstop — nothing painted can visually escape the frame regardless of any future edge case.

**Phase 8 exit criteria:** met — Stage 1 code/tests done, on-device review done, every issue it surfaced fixed and tested.

---

## Phase 9 — Question Database (Safe Sourcing Only) — not started

**Important boundary, carried over from an earlier discussion:** this table is for **generated and self-authored** content only — never scraped from copyrighted web pages, PDFs, or textbooks, even ones that appear "freely available." What this phase actually gives you is a place to **store and curate** questions that come from safe sources, not a scraper.

### What actually goes in this table
| Source | Allowed? | How it gets there |
|---|---|---|
| Output of your own generators (Phase 1, 7, 8) | ✅ | Optionally logged to the DB for reuse/curation, not required — they can also just be generated live |
| Questions you or a freelancer write yourself | ✅ | Manual entry via a simple admin form or a JSON import you author |
| Genuinely open-licensed sources (CC0, CC BY, CC BY-SA with attribution) | ✅, with attribution | Manual import |
| Anything scraped from a web page you don't own or hold a license to | ❌ | Not built — do not add a scraper for this |

### Step 9.1 — `questions` table schema
```
questions
├── id: string (uuid)
├── source: enum ["generated", "self_authored", "open_licensed"]
├── topic: enum [arithmetic, bodmas, area_volume, triangle, speed_distance, graph, profit_loss, interest, diagram]
├── questionText: string
├── diagramData: json?      // present only for diagram-based questions (Phase 8 geometry object)
├── options: array[string]
├── correctAnswerIndex: int
├── difficultyTier: int
├── licenseNote: string?     // required if source = "open_licensed"
├── createdAt: timestamp
```

### Step 9.2 — Simple admin import tool (not user-facing)
A small internal script (or a basic authenticated screen, gated behind a debug flag) that lets you paste a JSON batch of self-authored questions and validates: exactly 4 options, exactly 1 correct index, required `licenseNote` if source isn't "generated"/"self_authored".

### Step 9.3 — Wire the question bank into gameplay as a supplement
`PuzzleGenerator` gets a new option: pull occasionally from the curated `questions` table (e.g. 1 in 10 rounds) alongside live-generated puzzles.

**Phase 9 exit criteria:** not started — no schema, no import tool, no wiring.

---

## Phase 10 — Geometry, Probability & Ratio (real-life topics) — ✅ Built

**Goal:** round out the topic library with three more exam-relevant categories, each deliberately framed as a real-life word problem (a fenced garden, a bag of colored balls, a shared allowance) rather than an abstract formula prompt — same non-diagram shape as Phase 7's BODMAS/speed/profit-loss/interest generators, so no new rendering surface was needed.

| Topic | Generator | Real-life sub-cases | Notes |
|---|---|---|---|
| Geometry — perimeter | `lib/services/perimeter_generator.dart` | Fencing a rectangular garden; ribbon around a square photo frame; walking the boundary of a triangular park | Deliberately separate from Phase 8's `areaVolume` (distance *around* a shape vs. the space it covers). Triangle sides are drawn close together around a random base so the triangle inequality always holds without a retry loop. |
| Probability | `lib/services/probability_generator.dart` | Rolling a fair die; drawing from a bag of colored balls; drawing a card from a standard 52-card deck | The only generator in the app whose `correctAnswer` is a fraction string (e.g. `"1/3"`) rather than an int — reduced via a new shared `gcd()` helper in `rng_utils.dart`. Distractors are common real mistakes (the complement/favourable-unfavourable mix-up, off-by-one outcome counts), each independently reduced so none accidentally collides with the correct answer. |
| Ratio | `lib/services/ratio_generator.dart` | Scaling a recipe for more people; sharing money between two people in a given ratio; reading a map's scale | Same "generate the clean multiplier first, derive the rest" rule as `ProfitLossGenerator` — every answer is an exact integer, never rounded. |

**Testing**: same shared-harness pattern as Phase 7 — `perimeter` and `ratio` got a case added to `puzzle_generator_test.dart`'s `_independentlyVerify` switch and are covered by its existing 500-generation fuzz/determinism/anti-duplicate/hint-gating loop. `probability` is excluded from that file's anti-duplicate check (the die sub-case alone has only 5 possible question texts, a birthday-paradox flake risk the same as `coordinateDistance`/`graphReading`) and instead gets its own `test/services/probability_generator_test.dart` covering text/answer variety over a larger sample and that every fraction option is already in lowest terms.

**Phase 10 exit criteria:** met — `flutter analyze` clean, all tests (359 total) passing.

---

## Master Checklist

- [x] Phases 0–6 (core build, playable UI, daily challenge, ads, polish, store submission — see `ARCHITECTURE.md`)
- [x] Step 7.1 (partial): BODMAS, speed/distance, profit/loss, interest generators + shared-harness fuzz tests
- [ ] Step 7.3: topic selection UI (not started)
- [x] Step 8: diagram math (triangle law-of-sines placement, no library needed — geofig/p33 references corrected), `DiagramPainter` (`CustomPainter`, no charting package), 4 Stage-1 diagram types + tests, tier 3-4 hints, options-left/diagram-right layout
- [ ] **Gate: 20+ diagrams manually reviewed on a real device for legibility/layout correctness** — not yet done
- [ ] Stage 2 (diagram-as-answer-option: mirror/rotation/figure-series) — separate future scope, not started
- [ ] Phase 9 (question database) — not started
- [x] Phase 10: Geometry (perimeter), Probability, Ratio generators — real-life framed, `gcd()` helper added to `rng_utils.dart`, 359 tests passing

## How to Hand This to Claude Code

Same pattern as before:

> "Read ROADMAP_PHASE2.md. We're on [step] — build it exactly to the contract used by the existing generators, with matching fuzz tests. Do not proceed until tests pass."
