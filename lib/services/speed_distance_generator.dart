import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a relative-speed question — two trains/vehicles moving in the
/// same or opposite directions, asking for their relative speed. Same
/// direction subtracts, opposite adds — the answer is always derived from
/// that rule, never a separately-typed value.
abstract final class SpeedDistanceGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final range = _speedRangeForTier(tier);

    int speedA;
    int speedB;
    bool sameDirection;
    int relativeSpeed;
    // Retry only to avoid the degenerate "0 relative speed" case (two
    // identical speeds, same direction) — everything else about the pair
    // is always a valid question.
    do {
      speedA = rng.nextInt(range.min, range.max);
      speedB = rng.nextInt(range.min, range.max);
      sameDirection = rng.nextBool();
      relativeSpeed =
          sameDirection ? (speedA - speedB).abs() : speedA + speedB;
    } while (relativeSpeed == 0);

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.speedDistance,
      questionText: 'Train A runs at $speedA km/h, Train B at $speedB km/h, '
          '${sameDirection ? 'in the same direction' : 'in opposite directions'}. '
          "Find their relative speed.",
      options: buildNumericMcOptions(relativeSpeed, rng, spread: 15),
      correctAnswer: relativeSpeed,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: 'Same direction: subtract speeds. Opposite: add speeds.',
    );
  }

  /// TUNABLE — initial defaults. Wider speed ranges at higher tiers.
  static ({int min, int max}) _speedRangeForTier(int tier) => switch (tier) {
        1 => (min: 10, max: 40),
        2 => (min: 20, max: 60),
        3 => (min: 30, max: 90),
        _ => (min: 40, max: 120),
      };
}
