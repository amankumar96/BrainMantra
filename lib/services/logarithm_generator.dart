import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Logarithms (Phase 11B, topic 10): the product and quotient rules,
/// applied to given symbolic log values so every answer is an exact
/// integer sum/difference rather than a rounded decimal.
abstract final class LogarithmGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final range = _rangeForTier(tier);
    final logX = rng.nextInt(2, range);
    final logY = rng.nextInt(2, range);
    final isProduct = rng.nextBool();
    final answer = isProduct ? logX + logY : logX - logY;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.logarithm,
      questionText: isProduct
          ? 'If logₐx = $logX and logₐy = $logY, find logₐ(xy).'
          : 'If logₐx = $logX and logₐy = $logY, find logₐ(x/y).',
      options: buildNumericMcOptions(answer + 50, rng, spread: 6)
          .map((s) => (int.parse(s) - 50).toString())
          .toList(),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: isProduct
          ? 'logₐ(xy) = logₐx + logₐy'
          : 'logₐ(x/y) = logₐx - logₐy',
    );
  }

  static int _rangeForTier(int tier) => switch (tier) {
        1 => 8,
        2 => 12,
        3 => 18,
        _ => 25,
      };
}
