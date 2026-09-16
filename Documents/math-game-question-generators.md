# Math Game — Question Generator Upgrade Spec

**Purpose of this file:** This is a directive for Claude Code. It lists math topics and formulas
(sourced from a "Mathematical Formulas" reference sheet) that should power new question-generation
algorithms in the existing maths game app.

## Ground rule before implementing anything

Before adding a new generator for any topic below:
1. Search the existing codebase for a question generator already covering that exact topic/formula
   (e.g. `grep`/search by topic name, function name, or question-type enum).
2. **If it already exists and works correctly → skip it.** Do not duplicate.
3. **If it's missing, incomplete, or only partially covers the formulas listed here → build/extend it.**
4. For every new generator, also add: difficulty levels (easy/medium/hard), randomized numeric inputs
   within sane ranges, a validator for the correct answer, and at least 3 distractor (wrong-answer)
   generators for multiple-choice mode if the app uses MCQ format.
5. Keep each topic's generator in its own function/module so topics can be toggled independently in
   the game settings.

---

## 1. Number System
- Natural numbers (N): 1, 2, 3, 4, ...
- Whole numbers (W): 0, 1, 2, 3, 4, ...
- Integers (Z): ..., -2, -1, 0, 1, 2, ...
- Rational numbers (Q): p/q form, q ≠ 0
- Irrational numbers: non-terminating & non-repeating
- Real numbers (R): rational + irrational
- Complex numbers: z = a + ib, where i = √-1
- Laws of indices:
  - aᵐ × aⁿ = aᵐ⁺ⁿ
  - aᵐ ÷ aⁿ = aᵐ⁻ⁿ (a ≠ 0)
  - (aᵐ)ⁿ = aᵐⁿ
  - (ab)ⁿ = aⁿbⁿ
  - a⁰ = 1 (a ≠ 0)
  - (a/b)ⁿ = aⁿ/bⁿ (b ≠ 0)
  - a⁻ⁿ = 1/aⁿ (a ≠ 0)
- Prime numbers: 2, 3, 5, 7, 11, 13, ...

**Generator ideas:** classify a given number (natural/whole/integer/rational/irrational/prime),
simplify index expressions, evaluate aᵐ × aⁿ style problems, "is this number prime?" checks.

---

## 2. Surds and Indices
- √a × √b = √(ab)
- √a ÷ √b = √(a/b) (b ≠ 0)
- (√a)² = a
- a√a = a^(3/2) (a·√a)
- Important root values: √2 = 1.414, √3 = 1.732, √5 = 2.236, √7 = 2.645, √11 = 3.317

**Generator ideas:** simplify/combine surd expressions, estimate value using known roots, rationalize
denominators.

---

## 3. Algebraic Expressions
- (a+b)² = a² + 2ab + b²
- (a-b)² = a² - 2ab + b²
- (a+b)(a-b) = a² - b²
- (x+a)(x+b) = x² + (a+b)x + ab
- (x+a)(x-b) = x² + (a-b)x - ab

**Generator ideas:** expand a given binomial expression, factor a given expanded expression back,
fill-in-the-blank on identity terms, plug random a/b values and ask for the expanded/simplified result.

---

## 4. Linear Equations
- ax + b = 0 → x = -b/a
- ax + by + c = 0 (line form)
- Pair of linear equations: a₁x + b₁y + c₁ = 0, a₂x + b₂y + c₂ = 0
- Cross-multiplication solution: x/(b₁c₂ - b₂c₁) = y/(c₁a₂ - c₂a₁) = 1/(a₁b₂ - a₂b₁)

**Generator ideas:** solve for x in a single linear equation, generate a solvable pair of simultaneous
equations and ask for (x, y), ask to identify a/b/c coefficients from a given equation.

---

## 5. Quadratic Equations
- ax² + bx + c = 0
- x = [-b ± √(b² - 4ac)] / 2a
- Discriminant D = b² - 4ac
  - D > 0 → real & distinct roots
  - D = 0 → equal roots
  - D < 0 → imaginary roots

**Generator ideas:** generate random a,b,c (ensure integer/clean roots for easy mode, allow irrational
roots for hard mode), ask for roots via the quadratic formula, ask to classify nature of roots from D,
ask to form a quadratic given two roots.

---

## 6. Progressions (AP / GP)
**Arithmetic Progression (AP):**
- a, a+d, a+2d, ...
- nth term: aₙ = a + (n-1)d
- Sum: Sₙ = n/2 [2a + (n-1)d]

**Geometric Progression (GP):**
- a, ar, ar², ...
- nth term: aₙ = a·rⁿ⁻¹
- Sum: Sₙ = a(rⁿ - 1)/(r - 1), for r ≠ 1

**Generator ideas:** given a, d/r and n → ask for nth term or sum; given a sequence → ask to find
common difference/ratio; given aₙ and n → ask to find a or d.

---

## 7. Trigonometry
- sin²θ + cos²θ = 1
- 1 + tan²θ = sec²θ
- 1 + cot²θ = cosec²θ
- tanθ = sinθ/cosθ
- cotθ = cosθ/sinθ
- Standard angle table (0°, 30°, 45°, 60°, 90°) for sin, cos, tan, cosec, sec, cot
  (e.g. sin30° = 1/2, tan45° = 1, tan90° = not defined)

**Generator ideas:** ask for the value of a trig ratio at a standard angle, ask to apply a Pythagorean
identity to simplify an expression, "evaluate sinθ given cosθ" style problems using the identity.

---

## 8. Mensuration
**Circle:** Circumference = 2πr; Area = πr²; Diameter = 2r; Arc length = 2πr × (θ/360);
Sector area = πr² × (θ/360)

**Rectangle:** Perimeter = 2(l+b); Area = l×b; Diagonal = √(l²+b²)

**Triangle:** Area = ½×b×h; Heron's formula s = (a+b+c)/2, Area = √[s(s-a)(s-b)(s-c)]

**Parallelogram:** Area = b×h; Perimeter = 2(a+b)

**Trapezium:** Area = ½(a+b)×h

**Sphere:** Volume = (4/3)πr³; Surface area = 4πr²

**Cylinder:** Volume = πr²h; Curved surface area = 2πrh; Total surface area = 2πr(r+h)

**Cone:** Volume = (1/3)πr²h; Curved surface area = πrl; Total surface area = πr(r+l)

**Hemisphere:** Volume = (2/3)πr³; Curved surface area = 2πr²; Total surface area = 3πr²

**Generator ideas:** one generator per shape; randomize dimensions (keep them "nice" for easy mode,
e.g. multiples that give clean results), ask for area/perimeter/volume/surface area, and also reverse
questions (given area, find radius/side).

---

## 9. Coordinate Geometry
- Distance formula: d = √[(x₂-x₁)² + (y₂-y₁)²]
- Section formula: point dividing in ratio m:n = [(mx₂+nx₁)/(m+n), (my₂+ny₁)/(m+n)]
- Area of triangle from 3 points: ½|x₁(y₂-y₃) + x₂(y₃-y₁) + x₃(y₁-y₂)|
- Slope: m = (y₂-y₁)/(x₂-x₁)
- Equation of line: y = mx + c, or y - y₁ = m(x - x₁)
- Parallel lines: m₁ = m₂
- Perpendicular lines: m₁×m₂ = -1

**Generator ideas:** distance between two random points, area of triangle given 3 points, find slope
between two points, given a line's slope ask for the slope of a parallel/perpendicular line.

---

## 10. Logarithms
- logₐ(xy) = logₐx + logₐy
- logₐ(x/y) = logₐx - logₐy
- a^(logₐx) = x
- Common log values: log2 = 0.3010, log3 = 0.4771, log5 = 0.6990, log7 = 0.8451, log11 = 1.0414

**Generator ideas:** apply log product/quotient rules to simplify an expression, compute logₐ(x) using
provided common log values, solve simple log equations.

---

## 11. Progression / Series (additional section — "8. Progrision" on sheet, possibly duplicate)
- Note: sheet has a smaller secondary box labeled "8. Progrision" with formulas that render
  unclear/garbled in the source image (possible OCR/print artifact). Treat this as a supplementary
  reference only — cross-check with section 6 (Progressions) above before implementing; do not build
  a separate generator from unclear formulas.

---

## 12. Permutation & Combination
- Permutation: ⁿPᵣ = n!/(n-r)!
- ⁿP₀ = 1
- ⁿPₙ = n!
- Combination: ⁿCᵣ = n!/[r!(n-r)!]
- ⁿC₀ = 1
- ⁿCₙ = 1
- Sample values: ⁵C₀=1, ⁵C₁=5, ⁵C₂=10, ⁵C₃=10, ⁵C₄=5, ⁵C₅=1

**Generator ideas:** compute ⁿPᵣ or ⁿCᵣ for random small n and r, word-problem style ("in how many ways
can you choose r items from n"), verify symmetry property ⁿCᵣ = ⁿCₙ₋ᵣ.

---

## 13. Trigonometric Identities
- sin²θ + cos²θ = 1
- 1 + tan²θ = sec²θ
- 1 + cot²θ = cosec²θ
- Double angle: sin2θ = 2sinθcosθ; cos2θ = 1 - 2sin²θ; tan2θ = 2tanθ/(1 - tan²θ)
- Complementary angle rules: sin(90°-θ) = cosθ; cos(90°-θ) = sinθ; tan(90°-θ) = cotθ

**Generator ideas:** apply double-angle formulas given θ, simplify identity-based expressions,
complementary-angle substitution questions.

---

## 14. Statistics
- Mean: x̄ = Σx/n
- Median: for odd n → ((n+1)/2)th term; for even n → average of (n/2)th and (n/2 + 1)th terms
- Mode: most frequent value
- Range: L - H (largest - smallest, i.e. range = max - min)
- Variance: σ² = Σ(x - x̄)²/n
- Standard Deviation: σ = √variance

**Generator ideas:** generate a random small data set, ask for mean/median/mode/range, ask for
variance/standard deviation (keep dataset size small, e.g. 5–7 numbers, for manual solvability).

---

## 15. Useful Conversions (sheet section 16, first box)
- Percentage to Ratio: p% = p/100
- Ratio to Percentage: (a/b) → (a/b)×100%
- Average of ratio terms

**Generator ideas:** convert a given percentage to simplest ratio form and vice versa.

---

## 16. Work, Time, Pipe & Cistern
- Work: (A+B)'s combined work rate = A + B (in 1 day), i.e. combined rate = 1/A_days + 1/B_days
- Time = Work / Efficiency
- Pipe & Cistern: 1/t = 1/a + 1/b (combined fill/empty time)
- If A fills a tank in x days, A's rate = 1/x per day

**Generator ideas:** classic "A can do a job in x days, B in y days, how long together" problems;
pipe fills in x hrs, another empties in y hrs, net time to fill.

---

## 17. Simple & Compound Interest
- Simple Interest: SI = (P × R × T)/100
- Compound Interest: A = P(1 + R/100)ⁿ
- Difference: CI - SI = P(R/100)² × [multiplier depending on n] (for n=2: CI-SI = P(R/100)²)

**Generator ideas:** given P, R, T → compute SI; given P, R, n → compute CI and compound amount;
given SI and CI → find the difference; reverse problems (given SI find P or R or T).

---

## 18. Mixture & Alligation
- Alligation rule: Quantity of A / Quantity of B = (C - Mean) / (Mean - C_B) [cross-rule between two
  quantities and mean price]
- Average price = (x₁d₁ + x₂d₂ + ...)/(x₁ + x₂ + ...)

**Generator ideas:** two ingredients with given prices/concentrations mixed to hit a target mean —
ask for the mixing ratio; given ratio and two values, find the resultant average.

---

## 19. Geometry Formulas
- Triangle: Area = ½bh
- Right Triangle: a² + b² = c² (Pythagoras)
- Equilateral Triangle: Area = (√3/4)a²
- Circle: Area = πr²; Circumference = 2πr
- Regular Polygon: Area = ½ × a × p (a = apothem, p = perimeter)
- Rhombus: Area = ½ d₁d₂
- Square: Area = a²; Diagonal = a√2
- Rectangle: Area = l×b; Diagonal = √(l²+b²)

**Generator ideas:** overlaps with Mensuration (section 8) — check existing generators there first to
avoid duplication; this section adds Pythagoras, equilateral triangle, regular polygon, rhombus,
square-diagonal specifically — prioritize building those if missing.

---

## 20. Important Formulas (Algebraic Identities & Factorisation)
- a² - b² = (a-b)(a+b)
- a³ - b³ = (a-b)(a² + ab + b²)
- a³ + b³ = (a+b)(a² - ab + b²)
- x² + 2ax + a² = (x+a)²
- x² - 2ax + a² = (x-a)²

**Trigonometric ratios (SOH-CAH-TOA reference):**
- sinθ = opp/hyp, cosθ = adj/hyp
- tanθ = opp/adj, cotθ = adj/opp
- secθ = hyp/adj, cosecθ = hyp/opp

**Absolute value:**
- |x| = x (x ≥ 0)
- |x| = -x (x < 0)

**Generator ideas:** factorisation practice (give expanded form, ask factored, or vice versa),
identify correct trig ratio definition, evaluate |x| for random x including negatives.

---

## 21. Useful Unit Conversions
- Length: 1 km = 1000 m; 1 m = 100 cm; 1 cm = 10 mm
- Weight: 1 kg = 1000 g; 1 g = 1000 mg
- Time: 1 hour = 60 min = 3600 sec; 1 min = 60 sec
- Area: 1 m² = 10⁴ cm²; 1 hectare = 10⁴ m²
- Volume: 1 L = 1000 ml = 10⁶ cm³; 1 m³ = 10⁶ cm³

**Generator ideas:** unit conversion drills across length/weight/time/area/volume, both directions
(large→small and small→large units).

---

## 22. Quick Facts (Constants Reference)
- π ≈ 22/7 ≈ 3.1416
- √2 = 1.414, √3 = 1.732, √5 = 2.236, √7 = 2.645, √10 = 3.162

**Generator ideas:** not really question-worthy on its own — use as a shared constants module that
other generators (mensuration, surds, trigonometry) import for consistent precision/rounding.

---

## Implementation checklist for Claude Code

- [ ] Scan existing question-generator files/modules and map which of the 22 topics above already
      have working generators.
- [ ] For each **missing or weak** topic, create a generator function following the app's existing
      pattern (same file structure, naming convention, and difficulty/answer-validation approach used
      elsewhere in the codebase).
- [ ] Centralize shared constants (π, √2, √3, √5, √7, √10, common log values) in one module (see
      section 22) so all generators reference the same values.
- [ ] Add each new topic to the game's topic/category selector UI and settings if such a system
      exists.
- [ ] Write unit tests for each new generator verifying: correct answer computation, distractor
      generation (if MCQ), and edge cases (e.g. division by zero guards, r ≤ n for nCr, D<0 handling
      for quadratics).
- [ ] Do not duplicate any topic/formula already implemented — extend or refactor instead of
      recreating.

---

## Addendum (2026-09-16) — tier timing, hint policy, and the tier plan

Two explicit additions layered onto this spec, both built (Phase 11A in `ROADMAP_PHASE2.md`):

1. **Hints from tier 1**: every formula-driven generator now shows its formula as a hint at
   every tier, not just tier 3-4 — the formula name/statement itself doubles as the hint text,
   same as this spec's own "Generator ideas" already imply (e.g. `logₐ(xy) = logₐx + logₐy` is
   both the fact being tested and the hint for it).
2. **Timing, capped at 7 minutes total**: tier 1 = 1 min, tier 2 = 2 min, tier 3 = 5 min,
   tier 4 (and above) = 7 min. This game has exactly 4 tiers, so tier 4 is the ceiling — see
   `ROADMAP_PHASE2.md`'s Phase 11 for the full tier-to-topic mapping across all 22 topics above,
   worked out from each topic's genuine conceptual difficulty rather than this file's original
   flat topic list.
