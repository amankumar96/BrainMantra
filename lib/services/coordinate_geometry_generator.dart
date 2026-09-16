import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Coordinate Geometry (Phase 11B, topic 9): slope, the midpoint (section
/// formula with ratio 1:1), triangle area from 3 points, and — tier 3-4 —
/// the slope of a perpendicular line. Distinct from
/// `coordinate_distance_generator.dart` (the distance formula, Phase 8),
/// which this deliberately doesn't duplicate.
abstract final class CoordinateGeometryGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    if (tier >= 3 && rng.nextBool()) {
      return _perpendicularSlope(tier, params.timeLimitSeconds, rng);
    }
    return switch (rng.nextInt(0, 2)) {
      0 => _slope(tier, params.timeLimitSeconds, rng),
      1 => _midpoint(tier, params.timeLimitSeconds, rng),
      _ => _triangleArea(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _slope(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final x1 = rng.nextInt(-range, range);
    final y1 = rng.nextInt(-range, range);
    final m = rng.nextInt(-4, 4) == 0 ? 1 : rng.nextInt(-4, 4);
    final dx = rng.nextInt(1, 5);
    final x2 = x1 + dx;
    final y2 = y1 + m * dx;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.coordinateGeometry,
      questionText: 'Find the slope of the line through ($x1, $y1) and '
          '($x2, $y2).',
      options: buildNumericMcOptions(m + 20, rng, spread: 4)
          .map((s) => (int.parse(s) - 20).toString())
          .toList(),
      correctAnswer: m,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'm = (y₂-y₁)/(x₂-x₁)',
    );
  }

  static Puzzle _midpoint(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final x1 = rng.nextInt(-range, range);
    final y1 = rng.nextInt(-range, range);
    // x2/y2 kept the same parity as x1/y1 so the midpoint is always exact.
    final x2 = x1 + rng.nextInt(-range, range) * 2;
    final y2 = y1 + rng.nextInt(-range, range) * 2;
    final mx = (x1 + x2) ~/ 2;
    final wantsX = rng.nextBool();
    final answer = wantsX ? mx : (y1 + y2) ~/ 2;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.coordinateGeometry,
      questionText: 'Find the ${wantsX ? 'x' : 'y'}-coordinate of the '
          'midpoint of ($x1, $y1) and ($x2, $y2).',
      options: buildNumericMcOptions(answer + 100, rng, spread: 6)
          .map((s) => (int.parse(s) - 100).toString())
          .toList(),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Midpoint = [(x₁+x₂)/2, (y₁+y₂)/2] — the m:n=1:1 case of the '
          'section formula',
    );
  }

  static Puzzle _triangleArea(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    int x1, y1, x2, y2, x3, y3, area2;
    do {
      x1 = rng.nextInt(-range, range);
      y1 = rng.nextInt(-range, range);
      x2 = rng.nextInt(-range, range);
      y2 = rng.nextInt(-range, range);
      x3 = rng.nextInt(-range, range);
      y3 = rng.nextInt(-range, range);
      area2 = x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2);
    } while (area2 == 0); // retry on collinear (degenerate) points
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.coordinateGeometry,
      questionText: 'Find twice the area of the triangle with vertices '
          '($x1, $y1), ($x2, $y2), ($x3, $y3) — i.e. |x₁(y₂-y₃) + '
          'x₂(y₃-y₁) + x₃(y₁-y₂)|.',
      // Asking for 2×area (not area itself) sidesteps the "area is a
      // half-integer" case entirely, while still exercising the exact
      // same formula and staying an exact int answer.
      options: buildNumericMcOptions(area2.abs(), rng, spread: _spreadFor(area2.abs())),
      correctAnswer: area2.abs(),
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Area = ½|x₁(y₂-y₃) + x₂(y₃-y₁) + x₃(y₁-y₂)|',
    );
  }

  static Puzzle _perpendicularSlope(
    int tier,
    int timeLimitSeconds,
    RngService rng,
  ) {
    // Restricted to ±1..±4 so the perpendicular slope (-1/m) is always an
    // exact, cleanly-reduced fraction.
    final m = [1, 2, 3, 4, -1, -2, -3, -4][rng.nextInt(0, 7)];
    final correct = m > 0 ? '-1/$m' : '1/${-m}';
    final candidates = {
      correct,
      '$m',
      '-$m',
      '1/$m',
      '-1/${-m}',
    }..remove(correct);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.coordinateGeometry,
      questionText: 'A line has slope $m. What is the slope of a line '
          'perpendicular to it?',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Perpendicular lines: m₁ × m₂ = -1',
    );
  }

  static int _spreadFor(int answer) => (answer * 0.2).round().clamp(2, 100);

  static int _rangeForTier(int tier) => switch (tier) {
        1 => 6,
        2 => 10,
        3 => 15,
        _ => 20,
      };
}
