import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Algebraic Expressions & Identities (Phase 11B, topics 3 & 20): plug
/// random numbers into a standard identity and ask for the result — the
/// spec's own suggested approach, and the simplest way to keep every
/// answer an exact, self-validating integer without symbolic algebra.
abstract final class AlgebraicIdentityGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final range = _rangeForTier(tier);
    final x = rng.nextInt(range.min, range.max);
    final a = rng.nextInt(range.min, range.max);

    final (questionText, hint, answer) = switch (rng.nextInt(0, 3)) {
      0 => (
          'Using (x+a)² = x² + 2ax + a², find (x+a)² for x=$x, a=$a.',
          '(x+a)² = x² + 2ax + a²',
          x * x + 2 * x * a + a * a,
        ),
      1 => (
          'Using (x-a)² = x² - 2ax + a², find (x-a)² for x=$x, a=$a.',
          '(x-a)² = x² - 2ax + a²',
          x * x - 2 * x * a + a * a,
        ),
      // x kept >= a here so x²-a² never goes negative (this app never
      // shows a negative multiple-choice option).
      2 => (
          'Using (x+a)(x-a) = x² - a², find (x+a)(x-a) for x=${x + a}, a=$a.',
          '(x+a)(x-a) = x² - a²',
          (x + a) * (x + a) - a * a,
        ),
      _ => (
          'Using (x+a)(x+b) = x² + (a+b)x + ab, find (x+a)(x+a) for '
              'x=$x, a=$a (i.e. b=a).',
          '(x+a)(x+b) = x² + (a+b)x + ab',
          x * x + 2 * a * x + a * a,
        ),
    };

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.algebraicIdentity,
      questionText: questionText,
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: hint,
    );
  }

  static int _spreadFor(int answer) => (answer.abs() * 0.2).round().clamp(2, 100);

  static ({int min, int max}) _rangeForTier(int tier) => switch (tier) {
        1 => (min: 1, max: 8),
        2 => (min: 1, max: 12),
        3 => (min: 1, max: 20),
        _ => (min: 1, max: 30),
      };
}
