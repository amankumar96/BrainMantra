import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a ratio/proportion question — scaling a recipe, sharing money
/// between two people in a given ratio, or reading a map's scale (picked
/// at random each call). Every sub-case is constructed so the answer is
/// always an exact integer, never a rounded one — the scale factor (or
/// share count) is generated first and the rest derived from it, the same
/// "generate the clean number, derive everything else" rule
/// `ProfitLossGenerator` already follows.
abstract final class RatioGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);

    return switch (rng.nextInt(0, 2)) {
      0 => _recipeScaling(tier, params.timeLimitSeconds, rng),
      1 => _sharingMoney(tier, params.timeLimitSeconds, rng),
      _ => _mapScale(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _recipeScaling(
    int tier,
    int timeLimitSeconds,
    RngService rng,
  ) {
    final servesRange = _servesRangeForTier(tier);
    final baseServes = rng.nextInt(servesRange.min, servesRange.max);
    final baseCups = rng.nextInt(2, 12);
    // Scale by a clean integer factor so the new cup amount is always
    // exact — never a fraction of a cup.
    final factor = rng.nextInt(2, 4);
    final newServes = baseServes * factor;
    final newCups = baseCups * factor;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.ratio,
      questionText:
          'A recipe for $baseServes people needs $baseCups cups of flour. '
          'How many cups of flour are needed to make the same recipe for '
          '$newServes people?',
      options: buildNumericMcOptions(newCups, rng, spread: _spreadFor(newCups)),
      correctAnswer: newCups,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: tier >= 3
          ? 'Keep the ratio the same: new amount = old amount × '
              '(new servings ÷ old servings)'
          : null,
    );
  }

  static Puzzle _sharingMoney(
    int tier,
    int timeLimitSeconds,
    RngService rng,
  ) {
    final shareRange = _shareRangeForTier(tier);
    final ravi = rng.nextInt(1, shareRange.max);
    final sita = rng.nextInt(1, shareRange.max);
    final unit = rng.nextInt(shareRange.min, shareRange.max) * 10;
    final total = (ravi + sita) * unit;
    final raviAmount = ravi * unit;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.ratio,
      questionText: '₹$total is shared between Ravi and Sita in the ratio '
          '$ravi:$sita. How much money does Ravi get?',
      options:
          buildNumericMcOptions(raviAmount, rng, spread: _spreadFor(raviAmount)),
      correctAnswer: raviAmount,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: tier >= 3
          ? 'Split the total into (first share + second share) equal parts, '
              "then multiply by each person's share"
          : null,
    );
  }

  static Puzzle _mapScale(int tier, int timeLimitSeconds, RngService rng) {
    final scaleRange = _scaleRangeForTier(tier);
    final kmPerCm = rng.nextInt(scaleRange.min, scaleRange.max);
    final mapDistanceCm = rng.nextInt(2, 15);
    final actualDistanceKm = kmPerCm * mapDistanceCm;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.ratio,
      questionText:
          'On a map, 1 cm represents $kmPerCm km. If two towns are '
          '$mapDistanceCm cm apart on the map, what is the actual distance '
          'between them?',
      options: buildNumericMcOptions(actualDistanceKm, rng,
          spread: _spreadFor(actualDistanceKm)),
      correctAnswer: actualDistanceKm,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: tier >= 3
          ? 'Actual distance = map distance × scale (km per cm)'
          : null,
    );
  }

  static int _spreadFor(int answer) => (answer * 0.25).round().clamp(2, 200);

  /// TUNABLE — initial defaults.
  static ({int min, int max}) _servesRangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 4),
        2 => (min: 2, max: 6),
        3 => (min: 3, max: 8),
        _ => (min: 3, max: 10),
      };

  static ({int min, int max}) _shareRangeForTier(int tier) => switch (tier) {
        1 => (min: 1, max: 4),
        2 => (min: 1, max: 6),
        3 => (min: 1, max: 8),
        _ => (min: 1, max: 10),
      };

  static ({int min, int max}) _scaleRangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 5),
        2 => (min: 2, max: 10),
        3 => (min: 5, max: 20),
        _ => (min: 5, max: 40),
      };
}
