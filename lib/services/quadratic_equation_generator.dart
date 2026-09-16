import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Quadratic Equations (Phase 11B, topic 5): Vieta's-formula questions
/// (sum/product of roots — the "form an equation from given roots"
/// direction, avoiding the ± ambiguity of asking for "the" root) and
/// discriminant-based nature-of-roots classification.
abstract final class QuadraticEquationGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _vieta(tier, params.timeLimitSeconds, rng)
        : _discriminant(tier, params.timeLimitSeconds, rng);
  }

  /// x² + bx + c = 0 built from two chosen roots — sum = -b, product = c,
  /// by construction, so either question type is exact.
  static Puzzle _vieta(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rootRangeForTier(tier);
    final r1 = rng.nextInt(-range, range);
    final r2 = rng.nextInt(-range, range);
    final b = -(r1 + r2);
    final c = r1 * r2;
    final wantsSum = rng.nextBool();
    final answer = wantsSum ? r1 + r2 : c;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.quadraticEquation,
      questionText: 'For x² ${b >= 0 ? '+' : '-'} ${b.abs()}x '
          '${c >= 0 ? '+' : '-'} ${c.abs()} = 0, find the '
          '${wantsSum ? 'sum' : 'product'} of the roots.',
      options: buildNumericMcOptions(answer + 200, rng, spread: 10)
          .map((s) => (int.parse(s) - 200).toString())
          .toList(),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Sum of roots = -b/a, Product of roots = c/a',
    );
  }

  static Puzzle _discriminant(int tier, int timeLimitSeconds, RngService rng) {
    final range = _coeffRangeForTier(tier);
    final a = rng.nextInt(1, range);
    final b = rng.nextInt(-range * 2, range * 2);
    // 1 in 3 draws forces a perfect-square trinomial (D=0) so that
    // classification genuinely gets exercised, not just D>0/D<0.
    final c = rng.nextInt(0, 2) == 0 ? (b * b) ~/ (4 * a) : rng.nextInt(-range, range);
    final d = b * b - 4 * a * c;
    final correct = d > 0
        ? '2 distinct real roots'
        : d == 0
            ? '1 repeated real root'
            : 'No real roots';
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.quadraticEquation,
      questionText: 'How many real roots does ${a}x² ${b >= 0 ? '+' : '-'} '
          '${b.abs()}x ${c >= 0 ? '+' : '-'} ${c.abs()} = 0 have?',
      options: buildMcOptionsFromCandidates(
        correct,
        const [
          '2 distinct real roots',
          '1 repeated real root',
          'No real roots',
          'Infinitely many roots',
        ],
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Discriminant D = b² - 4ac. D>0: 2 roots, D=0: 1 root, D<0: none.',
    );
  }

  static int _rootRangeForTier(int tier) => switch (tier) {
        1 => 6,
        2 => 10,
        3 => 15,
        _ => 20,
      };

  static int _coeffRangeForTier(int tier) => switch (tier) {
        1 => 4,
        2 => 6,
        3 => 8,
        _ => 10,
      };
}
