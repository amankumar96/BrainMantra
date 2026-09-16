import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Linear Equations (Phase 11B, topic 4): a single ax+b=0 at every tier,
/// plus a solvable pair of simultaneous equations at tier 3-4 (the spec's
/// own tier-4 topic). Every equation is built by picking the *answer*
/// first and deriving coefficients from it, so the root is always exact.
abstract final class LinearEquationGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final wantsPair = tier >= 3 && rng.nextBool();
    return wantsPair
        ? _pair(tier, params.timeLimitSeconds, rng)
        : _single(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _single(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final a = rng.nextInt(2, range.maxCoefficient);
    final x = rng.nextInt(-range.maxRoot, range.maxRoot);
    final b = -a * x;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.linearEquation,
      questionText: 'Solve for x: ${a}x ${b >= 0 ? '+' : '-'} '
          '${b.abs()} = 0',
      options: buildNumericMcOptions(x + 100, rng, spread: 8)
          .map((s) => (int.parse(s) - 100).toString())
          .toList(),
      correctAnswer: x,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'ax + b = 0  →  x = -b/a',
    );
  }

  /// Builds two equations a1x+b1y=c1, a2x+b2y=c2 both satisfied by a
  /// chosen (x0, y0), with a1b2 - a2b1 guaranteed nonzero (a real,
  /// unique-solution system) — retried on the rare degenerate draw.
  static Puzzle _pair(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final x0 = rng.nextInt(-range.maxRoot, range.maxRoot);
    final y0 = rng.nextInt(-range.maxRoot, range.maxRoot);
    int a1, b1, a2, b2;
    do {
      a1 = rng.nextInt(1, range.maxCoefficient);
      b1 = rng.nextInt(1, range.maxCoefficient);
      a2 = rng.nextInt(1, range.maxCoefficient);
      b2 = rng.nextInt(1, range.maxCoefficient);
    } while (a1 * b2 - a2 * b1 == 0);
    final c1 = a1 * x0 + b1 * y0;
    final c2 = a2 * x0 + b2 * y0;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.linearEquation,
      questionText: 'Solve for x: ${a1}x + ${b1}y = $c1 and '
          '${a2}x + ${b2}y = $c2',
      options: buildNumericMcOptions(x0 + 100, rng, spread: 8)
          .map((s) => (int.parse(s) - 100).toString())
          .toList(),
      correctAnswer: x0,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'x/(b₁c₂ - b₂c₁) = y/(c₁a₂ - c₂a₁) = 1/(a₁b₂ - a₂b₁)',
    );
  }

  /// TUNABLE. `maxRoot` allows negative roots via buildNumericMcOptions'
  /// +100 offset trick, since that helper only builds non-negative
  /// distractors — shifting by a constant then shifting back keeps every
  /// candidate (including negative ones) reachable while reusing it.
  static ({int maxCoefficient, int maxRoot}) _rangeForTier(int tier) =>
      switch (tier) {
        1 => (maxCoefficient: 5, maxRoot: 10),
        2 => (maxCoefficient: 8, maxRoot: 15),
        3 => (maxCoefficient: 10, maxRoot: 20),
        _ => (maxCoefficient: 12, maxRoot: 25),
      };
}
