import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a triangle angle-finding question: two angles are shown, the
/// third is asked for. The third angle is always computed as
/// `180 - a - b` — the Angle Sum Property — never a separately-generated
/// value, so the diagram and the question can never drift out of sync.
abstract final class AngleFindingGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final step = _angleStepForTier(tier);

    // Regenerating on a degenerate third angle (too thin or too wide a
    // triangle to read comfortably) is the normal path, not an error —
    // same retry-loop pattern _generateFamilyTree uses in
    // puzzle_generator.dart.
    List<int>? angles;
    for (var attempt = 0; attempt < 30; attempt++) {
      final a = _roundToStep(rng.nextInt(20, 140), step);
      final b = _roundToStep(rng.nextInt(20, 140), step);
      final c = 180 - a - b;
      if (c >= 10 && c <= 150) {
        angles = [a, b, c];
        break;
      }
    }
    if (angles == null) {
      throw StateError('Could not build a valid triangle (tier $tier)');
    }

    final unknownIndex = rng.nextInt(0, 2);
    final known = [
      for (var i = 0; i < 3; i++) if (i != unknownIndex) angles[i],
    ];
    final correctAnswer = angles[unknownIndex];

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.angleFinding,
      questionText:
          'Two angles of a triangle are ${known[0]}° and ${known[1]}°. '
          'Find the third.',
      options: buildNumericMcOptions(correctAnswer, rng, spread: 15),
      correctAnswer: correctAnswer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.triangle,
        angles: angles.map((a) => a.toDouble()).toList(),
        unknownAngleIndex: unknownIndex,
      ),
      hint: tier >= 3
          ? 'Angle Sum Property: angles of a triangle add to 180°'
          : null,
    );
  }

  /// Rounds [value] to the nearest multiple of [step] (minimum 1).
  static int _roundToStep(int value, int step) {
    if (step <= 1) return value;
    return (value / step).round() * step;
  }

  /// TUNABLE — initial defaults: round-number angles (multiples of 10) at
  /// low tiers, arbitrary degrees at high tiers.
  static int _angleStepForTier(int tier) => switch (tier) {
        1 => 10,
        2 => 5,
        3 => 5,
        _ => 1,
      };
}
