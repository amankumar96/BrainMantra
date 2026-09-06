import 'rng_service.dart';

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

  /// Picks a tier *randomly* from a score-dependent band, rather than the
  /// single deterministic tier [tierForScore] returns — this is what lets
  /// a player occasionally see an easier or harder question than their
  /// score alone would imply, instead of a strict ladder. Used by
  /// `GameController` for **Play mode only** — Daily Challenge always
  /// uses [randomHighTier] instead, regardless of score.
  ///
  /// TUNABLE — initial bands/weights, not derived from an external spec:
  /// - score < 30: tiers 1-2 (60/40, easy-leaning)
  /// - 30 <= score < 300: tiers 2-4, broadly spread
  /// - score >= 300: tiers 1-4, weighted so 3-4 dominate ("mostly", not
  ///   exclusively — an easy question can still occasionally appear)
  static int randomTierForScore(int score, RngService rng) {
    if (score < 30) {
      return _weightedPick(rng, tiers: const [1, 2], weights: const [3, 2]);
    } else if (score < 300) {
      return _weightedPick(
        rng,
        tiers: const [2, 3, 4],
        weights: const [2, 2, 1],
      );
    } else {
      return _weightedPick(
        rng,
        tiers: const [1, 2, 3, 4],
        weights: const [1, 2, 4, 4],
      );
    }
  }

  /// Daily Challenge's tier picker — always tier 3 or 4 (evenly weighted),
  /// regardless of the player's score. Unlike [randomTierForScore], this
  /// ignores score entirely: Daily Challenge is meant to be consistently
  /// hard, not ramped like Play. TUNABLE: 50/50 is an initial default,
  /// easy to skew later without touching any caller.
  static int randomHighTier(RngService rng) {
    return _weightedPick(rng, tiers: const [3, 4], weights: const [1, 1]);
  }

  /// Rolls one value from [tiers], weighted by the parallel [weights] list
  /// — the same cumulative-weight technique `shape_reasoning_generator.dart`
  /// uses to weight (without excluding) simpler shapes at easier tiers.
  static int _weightedPick(
    RngService rng, {
    required List<int> tiers,
    required List<int> weights,
  }) {
    final totalWeight = weights.reduce((a, b) => a + b);
    var roll = rng.nextInt(0, totalWeight - 1);
    for (var i = 0; i < tiers.length; i++) {
      if (roll < weights[i]) return tiers[i];
      roll -= weights[i];
    }
    return tiers.last; // unreachable given the loop covers all weight
  }
}
