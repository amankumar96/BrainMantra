/// The four arithmetic operators a math puzzle can be built from.
enum MathOperator { add, subtract, multiply, divide }

/// Settings that shape a **math**-category puzzle at a given tier: how big
/// the numbers can be, and which operators are in play.
class MathParams {
  final int minOperand;
  final int maxOperand;
  final List<MathOperator> allowedOperators;

  const MathParams({
    required this.minOperand,
    required this.maxOperand,
    required this.allowedOperators,
  });
}

/// Settings that shape a **reasoning**-category puzzle at a given tier.
class ReasoningParams {
  /// How many relationship "hops" a family-tree question is allowed to
  /// span. 1 = direct relations only (parent/child/sibling/spouse).
  /// 2 = also in-laws and grandparents. 3 = also uncles/aunts/cousins.
  /// 4 = also great-grandparents and deeper multi-hop chains.
  final int familyTreeHopDepth;

  /// The range of side-counts a shape-identification question is allowed
  /// to draw from (inclusive both ends) — e.g. tier 1 sticks to simple
  /// shapes (3–6 sides), tier 4 opens up to decagons (3–10 sides).
  final int shapeMinSides;
  final int shapeMaxSides;

  const ReasoningParams({
    required this.familyTreeHopDepth,
    required this.shapeMinSides,
    required this.shapeMaxSides,
  });
}

/// The complete bundle of settings for one difficulty tier — everything a
/// puzzle generator needs to build a puzzle "at the right difficulty",
/// for either category.
class DifficultyParams {
  final int tier;

  /// How many seconds the player gets to answer at this tier. A single
  /// value shared by both categories, since [Puzzle] only carries one
  /// `timeLimitSeconds` field regardless of which category the puzzle is.
  final int timeLimitSeconds;

  final MathParams math;
  final ReasoningParams reasoning;

  const DifficultyParams({
    required this.tier,
    required this.timeLimitSeconds,
    required this.math,
    required this.reasoning,
  });
}

/// Translates a player's score (or an explicit tier number) into concrete
/// generation settings.
///
/// The four-tier table below is an **initial, tunable default** — no
/// externally-specified "Easy–Insane table" exists elsewhere in the
/// project's design docs, so these numbers were chosen as a reasonable
/// starting point for playtesting, not derived from anything else. Adjust
/// freely; nothing else in the codebase depends on the exact values, only
/// on the shape of [DifficultyParams].
abstract final class DifficultyCurve {
  // TUNABLE — initial defaults, not derived from an external spec.
  // Score thresholds a player must reach to enter each tier. tierForScore
  // walks this from the top down, so reaching a threshold exactly bumps
  // the player up (matches the doc's "score at threshold -> tier
  // increments" requirement).
  static const List<int> _tierScoreThresholds = [0, 100, 300, 600];

  // TUNABLE — initial defaults. Index 0 = tier 1, index 3 = tier 4.
  static const List<DifficultyParams> _paramsByTier = [
    DifficultyParams(
      tier: 1,
      timeLimitSeconds: 120, // 2 min — exam-style pacing (Phase 2 amendment)
      math: MathParams(
        minOperand: 1,
        maxOperand: 10,
        allowedOperators: [MathOperator.add, MathOperator.subtract],
      ),
      reasoning: ReasoningParams(
        familyTreeHopDepth: 1,
        shapeMinSides: 3,
        shapeMaxSides: 6,
      ),
    ),
    DifficultyParams(
      tier: 2,
      timeLimitSeconds: 600, // 10 min
      math: MathParams(
        minOperand: 2,
        maxOperand: 20,
        allowedOperators: [
          MathOperator.add,
          MathOperator.subtract,
          MathOperator.multiply,
        ],
      ),
      reasoning: ReasoningParams(
        familyTreeHopDepth: 2,
        shapeMinSides: 3,
        shapeMaxSides: 8,
      ),
    ),
    DifficultyParams(
      tier: 3,
      timeLimitSeconds: 1200, // 20 min
      math: MathParams(
        minOperand: 5,
        maxOperand: 50,
        allowedOperators: [
          MathOperator.add,
          MathOperator.subtract,
          MathOperator.multiply,
          MathOperator.divide,
        ],
      ),
      reasoning: ReasoningParams(
        familyTreeHopDepth: 3,
        shapeMinSides: 3,
        shapeMaxSides: 9,
      ),
    ),
    DifficultyParams(
      tier: 4,
      timeLimitSeconds: 1800, // 30 min
      math: MathParams(
        minOperand: 10,
        maxOperand: 100,
        allowedOperators: [
          MathOperator.add,
          MathOperator.subtract,
          MathOperator.multiply,
          MathOperator.divide,
        ],
      ),
      reasoning: ReasoningParams(
        familyTreeHopDepth: 4,
        shapeMinSides: 3,
        shapeMaxSides: 10,
      ),
    ),
  ];

  /// Which tier (1–4) a player at [score] currently belongs to.
  static int tierForScore(int score) {
    // Walk the thresholds from the highest down; the first one the score
    // meets or exceeds is the player's tier. This naturally makes hitting
    // a threshold exactly (e.g. score == 100) count as the *next* tier,
    // not the one below it.
    for (var tier = _tierScoreThresholds.length; tier >= 1; tier--) {
      if (score >= _tierScoreThresholds[tier - 1]) {
        return tier;
      }
    }
    return 1; // unreachable in practice (threshold[0] is 0), but a safe floor
  }

  /// The full settings bundle for [tier]. Out-of-range tiers are clamped
  /// to the nearest valid tier (1–4) rather than throwing — callers should
  /// never crash the game over a stray tier value.
  static DifficultyParams paramsForTier(int tier) {
    final clamped = tier.clamp(1, _paramsByTier.length);
    return _paramsByTier[clamped - 1];
  }
}
