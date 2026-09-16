import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a "distance from the origin" question. Points are drawn from a
/// fixed table of Pythagorean triples — e.g. (3, 4) → 5 — rather than
/// arbitrary coordinates, so the answer is always a clean whole number
/// (an arbitrary point's distance is almost never an integer). The triple
/// table itself is the self-validation: `a² + b² = c²` holds by
/// construction for every entry, never computed and hoped-for.
abstract final class CoordinateDistanceGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final triples = _triplesForTier(tier);
    final triple = triples[rng.nextInt(0, triples.length - 1)];

    // Randomize which leg lands on x vs y, so the same triple doesn't
    // always render identically.
    final swap = rng.nextBool();
    final x = swap ? triple.b : triple.a;
    final y = swap ? triple.a : triple.b;

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.coordinateDistance,
      questionText:
          'A point is plotted at ($x, $y). Find its distance from the origin.',
      options: buildNumericMcOptions(triple.c, rng, spread: 6),
      correctAnswer: triple.c,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.coordinatePoint,
        x: x.toDouble(),
        y: y.toDouble(),
      ),
      hint: 'Pythagorean Theorem: a² + b² = c²',
    );
  }

  /// TUNABLE — initial defaults: the classic small triple at low tiers,
  /// larger/less-obvious ones at high tiers.
  static List<({int a, int b, int c})> _triplesForTier(int tier) =>
      switch (tier) {
        1 || 2 => const [
            (a: 3, b: 4, c: 5),
            (a: 6, b: 8, c: 10),
            (a: 5, b: 12, c: 13),
          ],
        _ => const [
            (a: 8, b: 15, c: 17),
            (a: 7, b: 24, c: 25),
            (a: 9, b: 12, c: 15),
            (a: 20, b: 21, c: 29),
            (a: 12, b: 16, c: 20),
          ],
      };
}
