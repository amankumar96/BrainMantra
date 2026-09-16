import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Permutation & Combination (Phase 11B, topic 12): ⁿPᵣ and ⁿCᵣ for small
/// n (kept <= 10, so n! never risks overflow and results stay readable).
abstract final class PermutationCombinationGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final maxN = _maxNForTier(tier);
    final n = rng.nextInt(3, maxN);
    final r = rng.nextInt(1, n);
    final wantsPermutation = rng.nextBool();
    final answer = wantsPermutation ? _nPr(n, r) : _nCr(n, r);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.permutationCombination,
      questionText: wantsPermutation
          ? 'In how many ways can you arrange $r items chosen from $n '
              'distinct items (order matters)? Find ⁿPᵣ for n=$n, r=$r.'
          : 'In how many ways can you choose $r items from $n distinct '
              'items (order does not matter)? Find ⁿCᵣ for n=$n, r=$r.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: wantsPermutation
          ? 'ⁿPᵣ = n! / (n-r)!'
          : 'ⁿCᵣ = n! / [r!(n-r)!]',
    );
  }

  static int _factorial(int n) {
    var result = 1;
    for (var i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  static int _nPr(int n, int r) => _factorial(n) ~/ _factorial(n - r);
  static int _nCr(int n, int r) => _nPr(n, r) ~/ _factorial(r);

  static int _spreadFor(int answer) => (answer * 0.3).round().clamp(2, 500);

  /// TUNABLE — n capped at 10 (10! = 3,628,800, well within int range,
  /// and ⁿPᵣ options stay readable for multiple-choice).
  static int _maxNForTier(int tier) => switch (tier) {
        1 => 5,
        2 => 6,
        3 => 8,
        _ => 10,
      };
}
