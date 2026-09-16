import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Paper Folding & Cutting (Phase 12, reasoning topic 2): the classic
/// "fold n times, punch a hole through every layer, how many holes when
/// unfolded" puzzle — answer is always exactly holes × 2ⁿ, so this stays
/// fully text/number-based (no rendered fold diagram needed).
abstract final class PaperFoldingGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final maxFolds = switch (tier) {
      1 => 2,
      2 => 3,
      3 => 4,
      _ => 5,
    };
    final folds = rng.nextInt(1, maxFolds);
    final holesPunched = tier >= 3 ? rng.nextInt(1, 2) : 1;
    var answer = holesPunched;
    for (var i = 0; i < folds; i++) {
      answer *= 2;
    }
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.paperFolding,
      questionText: 'A square paper is folded in half $folds time'
          '${folds == 1 ? '' : 's'}. $holesPunched hole'
          '${holesPunched == 1 ? ' is' : 's are'} then punched through '
          'all the folded layers. How many holes will there be when the '
          'paper is fully unfolded?',
      options: buildNumericMcOptions(answer, rng, spread: (answer * 0.5).round().clamp(2, 50)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: 'Holes when unfolded = (holes punched) × 2^(number of folds)',
    );
  }
}
