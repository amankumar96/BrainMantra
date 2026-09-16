import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Surds and Indices (Phase 11B, topic 2): the product rule and
/// simplifying a surd to k√m form — both integer-clean by construction.
abstract final class SurdsGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _product(tier, params.timeLimitSeconds, rng)
        : _simplify(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _product(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final a = rng.nextInt(range.min, range.max);
    final b = rng.nextInt(range.min, range.max);
    final product = a * b;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.surds,
      questionText: '√$a × √$b = √?',
      options: buildNumericMcOptions(product, rng, spread: (product * 0.2).round().clamp(2, 40)),
      correctAnswer: product,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: '√a × √b = √(ab)',
    );
  }

  static Puzzle _simplify(int tier, int timeLimitSeconds, RngService rng) {
    // TUNABLE — coefficients/radicands scaled by tier.
    final kRange = tier <= 2 ? (min: 2, max: 5) : (min: 3, max: 9);
    const radicands = [2, 3, 5, 6, 7, 10, 11, 13];
    final k = rng.nextInt(kRange.min, kRange.max);
    final m = radicands[rng.nextInt(0, radicands.length - 1)];
    final n = k * k * m;
    final correct = '$k√$m';
    final candidates = <String>{
      '${k + 1}√$m',
      '${(k - 1).clamp(1, 999)}√$m',
      '$k√${radicands[(radicands.indexOf(m) + 1) % radicands.length]}',
      '$n√1',
    }..remove(correct);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.surds,
      questionText: 'Simplify √$n to the form k√m.',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: '√(k²m) = k√m',
    );
  }

  static ({int min, int max}) _rangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 8),
        2 => (min: 2, max: 12),
        3 => (min: 2, max: 15),
        _ => (min: 2, max: 20),
      };
}
