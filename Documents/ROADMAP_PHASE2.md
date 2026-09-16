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
- **Stage 2 (✅ built — see Phase 13) — diagram-as-answer-option.** The four *options themselves* are little rendered diagrams — `Puzzle.optionDiagrams` and the `DiagramAnswerButton` widget this section originally scoped, built out for `mirrorImage`.

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

## Phase 11 — Tier Plan, Timing/Hint Policy & the 22-Topic Roadmap

Sourced from `math-game-question-generators.md` (a directive spec listing 22 math topics/formula
groups pulled from a "Mathematical Formulas" reference sheet, plus explicit timing and hint
requirements). Two parts, both ✅ built: **(A)** the timing/hint policy change, applied to every
existing generator; **(B)** the 22-topic-to-tier mapping, and all 15 new generators built from it.

### A. Timing & hint policy — ✅ Built

- **Timing, tightened** (`difficulty_curve.dart`'s `_paramsByTier`): tier 1 = 60s (was 120s/2min),
  tier 2 = 120s (was 600s/10min), tier 3 = 300s (was 1200s/20min), tier 4 = 420s/7min — the ceiling
  for the whole game (was 1800s/30min). This game has exactly 4 tiers
  (`DifficultyCurve.paramsForTier` clamps 1-4) — tier 4 simply *is* the "tier 4 and above" ceiling
  from the spec, not a placeholder for a 5th tier.
- **Hints, no longer tier-gated**: every one of the 10 existing formula-driven generators
  (`bodmas`, `speedDistance`, `profitLoss`, `interest`, `perimeter`, `probability`, `ratio`,
  `angleFinding`, `areaVolume`, `coordinateDistance`) now populates `Puzzle.hint` at **every** tier,
  not just tier 3-4 — the `tier >= 3 ? '...' : null` gate was removed from each generator's `hint:`
  field. `graphReading` (reading a graph isn't formula-driven) and the original arithmetic/pattern
  types (never had a formula-based hint at all) are unaffected. `puzzle_generator_test.dart`'s shared
  hint-gating check updated to match: `hint` is always non-null/non-empty for every hinted type now,
  at every tier, rather than only tier 3+.

### B. Topic-to-tier mapping for the 22-topic spec — ✅ Built

The spec's own 22 topics were grouped into 15 new `PuzzleType`s by related formula, the same "one
PuzzleType, several sub-cases" shape `areaVolume`/`ratio`/`probability` already use — mapped onto the
4 tiers below by genuine conceptual difficulty (a topic's *easiest* questions can still appear one
tier down from where it's listed, this is about where each topic's *center of mass* sits):

| Tier | Topics | Generator |
|---|---|---|
| **1** (60s) | Number classification (N/W/Z/prime checks); percentage↔ratio, length/weight/time conversions | `number_classification_generator.dart`, `unit_conversion_generator.dart` |
| **2** (120s) | Algebraic identity expansion; single-variable linear equations; standard-angle trig lookups; surds (product rule, k√m simplification); work/time & pipe-cistern | `algebraic_identity_generator.dart`, `linear_equation_generator.dart`, `trig_ratio_generator.dart`, `surds_generator.dart`, `work_time_generator.dart` |
| **3** (300s/5min) | Quadratic equations (Vieta's formulas, discriminant classification); AP/GP nth-term and sum; coordinate geometry (slope, midpoint, triangle area); logarithm product/quotient rules; sphere/cone/hemisphere/Heron's-formula/rhombus mensuration; mixture & alligation; Pythagorean trig identity | `quadratic_equation_generator.dart`, `progression_generator.dart`, `coordinate_geometry_generator.dart`, `logarithm_generator.dart`, `mensuration_advanced_generator.dart`, `mixture_alligation_generator.dart` |
| **4** (420s/7min) | Permutation & Combination; pair of linear equations (cross-multiplication); double-angle trig identity; perpendicular-line slope; statistics variance | `permutation_combination_generator.dart`, `linear_equation_generator.dart` (pair sub-case), `trig_ratio_generator.dart`/`coordinate_geometry_generator.dart` (tier-gated sub-cases), `statistics_generator.dart` |

`statistics_generator.dart` also covers mean/median/mode/range (tier 1-4, no tier gate on which
sub-case can appear — only variance is tier 3-4-only).

**Every answer is exact, never hardcoded** — the same discipline as every prior generator, achieved
by picking the *answer* first and deriving the question from it wherever a formula doesn't already
guarantee an exact result: quadratic roots via Vieta's formulas (never solving for an actual root, so
no ± ambiguity), cone/mensuration dimensions drawn from Pythagorean triples (never a rounded
`√(r²+h²)`), work/time and pipe-cistern problems drawn from curated (individual-time, combined-time)
pairs verified to divide evenly, Heron's-formula triangles from a table of integer-area triangles,
and every fraction/ratio answer reduced via the shared `gcd()` helper.

**Hints**: every generator populates a formula-text hint at every tier, per Part A's policy.

**Testing**: no dedicated test file per generator (matching Phase 7's convention) — every new type
gets a case in `puzzle_generator_test.dart`'s shared `_independentlyVerify` switch, covered by its
500-generation fuzz/determinism loop. Five types (`numberClassification`, `trigRatio`, `workTime`,
and the pre-existing `probability`/`graphReading`/`coordinateDistance`/`shapeIdentification`) are
excluded from the shared anti-duplicate check for the same birthday-paradox reason as before — each
draws from a small fixed table/range rather than a wide one. One real bug caught by the fuzz suite
along the way: `StatisticsGenerator._mode`'s three "other" values weren't guaranteed distinct from
each other, so two could tie with the true mode — fixed by generating them into a `Set`.

**Phase 11 exit criteria:** met — Parts A and B both built, `flutter analyze` clean, all 453 tests
passing.

---

## Phase 12 — Reasoning Category Rebalance + 10 New Reasoning Topics — ✅ Built

Phase 11B's 15 new math topics left `PuzzleType.values` badly lopsided (~25 math types vs. 12
reasoning types) — `GameController._pickNextType()` picked uniformly across *every* type, so math
would have dominated. Two parts, both built:

### A. Category-balanced picker

`GameController._pickNextType()` now picks the *category* first (50/50 math vs. reasoning), then
uniformly within it — regardless of how many topics either side has. New
`test/controllers/game_controller_test.dart` coverage: over 200 draws, both categories land in a
generous 30-70% band (not a strict alternation, still genuinely random within each pick).

### B. 10 new reasoning generators

All sourced from the same well-established verbal/logical-reasoning question formats real reasoning
tests use — **text-based by design**, not a placeholder for rendered images. Three of the ten (mirror
images, paper folding, figure series) are topics that could *also* be asked as literal rendered
figures, but that needed the diagram-as-answer-option infrastructure this project's Stage 2 diagram
work (see Phase 8) hadn't built yet at the time — these use the standard textual equivalents real
test-prep material already treats as the same skill, not a workaround. (Stage 2 was built shortly
after, in Phase 13 below — `mirrorImage` was rebuilt on top of it as the proof case; `paperFolding`
and `figureSeries` still use their text-based form here, which remains a legitimate implementation on
its own.)

| Generator | Format | Diagram-would-need-Stage-2? |
|---|---|---|
| `mirror_image_generator.dart` | letter-symmetry lookup (vertical/water mirror), b↔d/p↔q pairs | Yes for arbitrary rendered figures |
| `paper_folding_generator.dart` | fold-and-punch hole-count (holes × 2ⁿ) | Yes for a rendered fold diagram |
| `figure_series_generator.dart` | letter series (A, C, E, G, ?) — the standard analog to a figure series | Yes for rendered figures |
| `seating_arrangement_generator.dart` | stated row order; neighbor/between/position questions | No |
| `coding_generator.dart` | letter-shift cipher, A=1..Z=26 number coding | No |
| `direction_sense_generator.dart` | perpendicular-walk displacement (Pythagorean triples), turn-tracking | No |
| `word_puzzle_generator.dart` | odd-word-out from a curated category bank | No |
| `analogy_generator.dart` | A:B::C:D from a curated relationship bank | No |
| `ranking_generator.dart` | rank-from-other-end conversion, comparative chains | No |
| `statement_conclusion_generator.dart` | basic syllogism validity (True/False) | No |

Every answer is exact by construction (letter-symmetry/pair tables, Pythagorean triples for direction
sense, curated banks for word/analogy/statement puzzles so nothing depends on ambiguous real-world
knowledge). Same testing convention as Phase 11B — a case per type in
`puzzle_generator_test.dart`'s shared `_independentlyVerify` switch, covered by the 500-generation
fuzz loop. Five of the ten (`mirrorImage`, `paperFolding`, `wordPuzzle`, `analogy`,
`statementConclusion`) join the anti-duplicate exclusion list — most for the same reason as earlier
exclusions (small curated banks), `mirrorImage`/`wordPuzzle` specifically because their fixed question
stems put all the real variety in `options`/`correctAnswer`, not `questionText`.

### C. Score-to-tier bands, simplified

`DifficultyCurve.randomTierForScore` (Play mode's difficulty ramp) replaced its earlier 30/300
threshold bands with an explicit, much tighter spec: score < 50 → tier 1 only; 50-100 inclusive →
tier 1 or 2 (evenly split); score > 100 → tier 3 or 4 (evenly split, "tier 3 and above"). A
deliberately faster ramp than before, matching Phase 11A's tightened per-question timing (1/2/5/7 min
instead of 2/10/20/30 min) — this game now expects a player to reach harder material much sooner.
`tierForScore` (a separate, deterministic helper — not actually called by game logic, only exercised
by its own tests) was left unchanged. `difficulty_curve_test.dart`'s `randomTierForScore` group
rewritten to match: below-50/49-boundary/50-100-band/above-100/101-boundary/negative-score cases.

**Phase 12 exit criteria:** met — all three parts built, `flutter analyze` clean, all 511 tests passing.

---

## Phase 13 — Diagram-as-Answer-Option ✅ Built

The Stage 2 work flagged as not-yet-built back in Phase 8 — a multiple-choice question whose 4
*options* are themselves small rendered diagrams, not text. `mirrorImage` was rebuilt on top of it as
the proof case (a genuinely visual reasoning topic, not a text stand-in anymore); `paperFolding` and
`figureSeries` stay text-based, which is still their own honest, tested implementation.

**Model**: `Puzzle` gained `optionDiagrams` (`List<DiagramData>?`, one entry per `options[i]`, same
order — additive, `null` for every other puzzle type) and `DiagramData` gained a `polygon` kind
holding flattened `[x0,y0,x1,y1,...]` vertices in an arbitrary unit scale. `options[i]` is purely an
internal selection/correctness key when `optionDiagrams` is set — the id string is never shown to the
player, only the rendered shape is.

**Painter**: `diagram_painter.dart` gained `polygonPoints()` (a top-level pure function, same
"measure the real bounding box first, then pick one scale for both axes" technique `trianglePoints`
already used, generalized to any vertex count and any coordinate scale — including negative
coordinates, since a flipped shape's vertices are exactly that) and `_paintPolygon` (a light fill +
stroke outline, since a small option-sized shape has no room for the angle/length labels the other
diagrams rely on for legibility).

**Widget**: `DiagramAnswerButton` (new, in `answer_button.dart`) — shares `AnswerButton`'s exact color
states via an extracted `colorsForAnswerState()` helper, so text and diagram options read as the same
visual family. Always wrapped in an `AspectRatio`-driven grid cell by its caller and backed by a hard
`ClipRect`, so every option is the same uniform square regardless of the shape drawn inside it — a
shape can never make its own box irregular or spill past its border.

**Layout**: `game_screen.dart`'s `_QuestionAndOptions` gained a third branch (alongside the existing
"diagram-in-question" and "plain text options" layouts): when `optionDiagrams` is set, an optional
reference-shape diagram (`puzzle.diagramData` — e.g. the original, un-mirrored figure) renders above a
`GridView.count(crossAxisCount: 2, childAspectRatio: 1)` of 4 `DiagramAnswerButton`s — a fixed, uniform
2x2 block, never a ragged list.

**Generator**: `mirror_image_generator.dart` rewritten around 3 hand-picked asymmetric polygon
templates (asymmetric so a flip is actually visually consequential) and pure coordinate-flip
arithmetic — mirror image = `(x,y) → (−x,y)`, water image = `(x,y) → (x,−y)` — with distractors built
from the original (unflipped), the wrong flip axis, and a 180° rotation. Every option's shape is
derived from the same reference vertices the question shows, never invented independently.

**Testing**: `puzzle_generator_test.dart`'s `mirrorImage` case now re-derives the correct option's
vertices independently (flip the reference shape's own vertices by the axis the question text names,
compare to the option at `correctAnswer`'s index) rather than checking a letter table. New coverage:
`diagram_painter_test.dart` (polygon paints without throwing + `polygonPoints` containment across 5
shapes × 3 box sizes, including negative-coordinate/flipped shapes and a small 80×80 answer-option-
sized box), `answer_button_test.dart` (`DiagramAnswerButton` tap/disabled/ClipRect-present coverage),
and `game_screen_test.dart` (end-to-end: exactly 5 `DiagramPainter`-backed `CustomPaint`s render — 1
reference + 4 options — no option id text ever shown, and tapping one actually selects it).

**Phase 13 exit criteria:** met — `flutter analyze` clean, all 531 tests passing.

---

## Phase 14 — Paper Folding & Figure Series as Rendered Diagrams ✅ Built

The two reasoning topics Phase 13 deliberately left text-based (`paperFolding`, `figureSeries`) rebuilt
onto the same diagram-as-answer-option architecture, so every diagram-shaped reasoning topic in the app
now actually looks like one.

**Model**: `DiagramData` gained two kinds. `dotGrid` (`points: List<double>?`) draws a bordered square
frame with dots at fixed `[0,1]`-fraction positions — unlike `polygon`'s `vertices`, a dot grid's
coordinate space is fixed, not fit-to-content, since a fold puzzle needs to show *where in the square*
each hole actually is, not just a shape's outline. `shapeSequence` (`sideCounts: List<int>?`) draws
several regular polygons left to right in one box, one entry per side count. A new top-level
`regularPolygonVertices(sides)` (in `diagram_data.dart`, alongside the model it serves) generates a
regular polygon inscribed in a unit circle, first vertex pointing up — the one shared definition of
"what a square/pentagon/hexagon looks like" both `figureSeries`' reference diagram and its rendered
option shapes draw from, so the two can never silently disagree.

**Painter**: `diagram_painter.dart` gained `_paintDotGrid` (a stroked frame + filled circles at each
scaled/offset point) and `_paintShapeSequence` (divides the box into equal cells, fits each cell's
polygon via the existing `polygonPoints()` from Phase 13 — no new fitting math needed).

**Generators**: `paperFolding` rebuilt around exact fold-mirroring math — a punch point `(px, py)` on a
clean eighths fraction, mirrored across whichever axis(es) the described fold(s) actually apply
(`(x,y) → (1-x,y)` for a vertical fold, `(x,y) → (x,1-y)` for horizontal) — with the reference diagram
showing the folded sheet's single punch point and each of the 4 options a full rendered unfold pattern.
`figureSeries` now draws from two sub-cases: a rendered shape-series (every tier — 3 polygons with a
constant side-count step, 1 at tier 1-2, 2 at tier 3-4, extrapolate the next) and the original
letter-series (`A, C, E, G, ?`) kept as an additional tier 3-4 sub-case for variety, since a written
"spot the pattern" puzzle still exercises the same skill differently. Two real bugs were caught and
fixed by manual review before ever running a test: `paperFolding`'s original distractor de-duplication
used a `Set<List<double>>`, which relies on Dart's identity-based (not value-based) `List.==` and could
have silently let a distractor share the correct answer's exact hole positions — fixed by excluding
distractors by fold-combo identity instead of by comparing the resulting lists. `figureSeries`' original
distractor side-counts used `.clamp(3, 10)` on offsets, which collapsed to fewer than 3 distinct values
near the range's edges (e.g. `correctSides = 10`) — fixed by drawing 3 distractors from the full
triangle..decagon range minus the correct answer, shuffled, guaranteeing exactly 3 every time.

**Testing**: `puzzle_generator_test.dart`'s `paperFolding` case now re-derives the correct option's hole
pattern independently — parses which fold(s) the question text names, re-mirrors the punch point itself,
and compares against the correct option's `points` — rather than trusting the generator's own fold
tracking. `figureSeries` branches on `diagramData?.kind`: the rendered sub-case re-derives the expected
next side count from the reference diagram's own `sideCounts` progression and checks the correct
option's vertex count matches; the letter sub-case keeps the original regex-based check unchanged.
`diagram_painter_test.dart` gained `dotGrid`/`shapeSequence` paint-without-throwing samples in
`_sampleByKind`, following the same pattern Phase 13 used for `polygon`. The anti-duplicate exclusion
list gained `figureSeries` (its rendered sub-case has one fixed questionText, same as `mirrorImage`'s
lookup sub-cases before it) alongside the already-excluded `paperFolding` (whose questionText is now one
of 3 fixed fold-description sentences, real variety living entirely in `diagramData`/`optionDiagrams`).
`game_screen_test.dart`'s generic seeded-puzzle tests (tap a correct/wrong answer, complete a session,
End a Play session) could now land on one of these diagram-as-answer-option types and find no
`find.text`-matchable option button — fixed with a small `_textOptionController` seed-search helper,
the same technique the file's existing diagram-search tests already used in the other direction.

**Phase 14 exit criteria:** met — `flutter analyze` clean, all 532 tests passing.

---

## Master Checklist

- [x] Phases 0–6 (core build, playable UI, daily challenge, ads, polish, store submission — see `ARCHITECTURE.md`)
- [x] Step 7.1 (partial): BODMAS, speed/distance, profit/loss, interest generators + shared-harness fuzz tests
- [ ] Step 7.3: topic selection UI (not started)
- [x] Step 8: diagram math (triangle law-of-sines placement, no library needed — geofig/p33 references corrected), `DiagramPainter` (`CustomPainter`, no charting package), 4 Stage-1 diagram types + tests, tier 3-4 hints, options-left/diagram-right layout
- [ ] **Gate: 20+ diagrams manually reviewed on a real device for legibility/layout correctness** — not yet done
- [x] Stage 2 (diagram-as-answer-option) — see Phase 13/14; `mirrorImage`, `paperFolding`, and `figureSeries`' rendered sub-case all rebuilt on it (rotation not built as a distinct topic)
- [ ] Phase 9 (question database) — not started
- [x] Phase 10: Geometry (perimeter), Probability, Ratio generators — real-life framed, `gcd()` helper added to `rng_utils.dart`, 359 tests passing
- [x] Phase 11A: tier timing tightened (1/2/5/7 min), hints unlocked at every tier for all 10 existing formula-driven generators — 366 tests passing
- [x] Phase 11B: 15 new generators covering the 22-topic spec (number classification, surds, algebraic identities, linear/quadratic equations, progressions, trig ratios/identities, advanced mensuration, coordinate geometry, logarithms, permutation & combination, statistics, unit conversions, work/time, mixture & alligation) — 453 tests passing
- [x] Phase 12: category-balanced type picker (math/reasoning 50/50), 10 new reasoning generators (mirror/water images, paper folding, figure series, seating arrangements, coding, direction sense, word puzzles, analogy, ranking, statement & conclusion), and a simplified score-to-tier band (<50→1, 50-100→1-2, >100→3-4) — 511 tests passing
- [x] Phase 13: diagram-as-answer-option (Stage 2) — `Puzzle.optionDiagrams`, `DiagramData.polygon`/`polygonPoints`, `DiagramAnswerButton`, a uniform 2x2 grid layout, `mirrorImage` rebuilt as a genuine rendered-shape puzzle — 531 tests passing
- [x] Phase 14: `paperFolding` and `figureSeries` rebuilt onto diagram-as-answer-option — `DiagramData.dotGrid`/`shapeSequence`, `regularPolygonVertices()`, exact fold-mirroring math, `figureSeries` gains a rendered shape-series at every tier (letter-series kept as an extra tier 3-4 sub-case) — 532 tests passing

## How to Hand This to Claude Code

Same pattern as before:

> "Read ROADMAP_PHASE2.md. We're on [step] — build it exactly to the contract used by the existing generators, with matching fuzz tests. Do not proceed until tests pass."
