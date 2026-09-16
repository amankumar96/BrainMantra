import 'dart:math' show pow;

import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a Simple or Compound Interest question (chosen at random each
/// call). SI is always an exact integer by construction (principal is
/// always a multiple of 100). CI generally isn't exact in real money —
/// rounded to the nearest whole rupee, same as this project's other
/// numeric answers (`Puzzle.correctAnswer` is always `int`, matching every
/// other math generator).
abstract final class InterestGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final ranges = _rangesForTier(tier);

    final principal = rng.nextInt(1, 10) * 1000;
    final rate = ranges.rates[rng.nextInt(0, ranges.rates.length - 1)];
    final years = rng.nextInt(1, ranges.maxYears);
    final wantsCompound = rng.nextBool();

    final int correctAnswer;
    final String questionText;
    final String hintText;
    if (wantsCompound) {
      final amount = principal * pow(1 + rate / 100, years);
      correctAnswer = (amount - principal).round();
      questionText = 'Find the compound interest on ₹$principal at $rate% '
          'for $years year${years == 1 ? '' : 's'}, compounded annually.';
      hintText = 'CI = P(1 + r/100)ᵗ − P';
    } else {
      correctAnswer = (principal ~/ 100) * rate * years;
      questionText = 'Find the simple interest on ₹$principal at $rate% '
          'for $years year${years == 1 ? '' : 's'}.';
      hintText = 'SI = PRT/100';
    }

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.interest,
      questionText: questionText,
      options: buildNumericMcOptions(correctAnswer, rng, spread: 20),
      correctAnswer: correctAnswer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: hintText,
    );
  }

  /// TUNABLE — initial defaults. Round rates and a short time span at low
  /// tiers; compounding grows harder mainly through `years`, since that's
  /// what makes CI diverge more visibly from SI.
  static ({List<int> rates, int maxYears}) _rangesForTier(int tier) =>
      switch (tier) {
        1 => (rates: const [5, 10], maxYears: 2),
        2 => (rates: const [5, 8, 10, 12], maxYears: 3),
        3 => (rates: const [4, 6, 8, 10, 12, 15], maxYears: 4),
        _ => (rates: const [4, 5, 6, 8, 10, 12, 15, 18], maxYears: 5),
      };
}
