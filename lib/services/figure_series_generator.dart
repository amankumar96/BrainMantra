import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Figure Matrix & Series (Phase 12 → Phase 14): a genuine rendered shape
/// progression (triangle → square → pentagon → ?, one more side each
/// time) at every tier, plus the original letter-series (A, C, E, G, ?)
/// kept as an additional tier 3-4 sub-case for variety — both exercise
/// the same "spot the pattern, extrapolate" skill, one drawn, one
/// written.
abstract final class FigureSeriesGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    // Letters only ever show up as one of two options at tier 3-4 — every
    // tier 1-2 draw, and half of tier 3-4's, is the rendered version.
    if (tier >= 3 && rng.nextBool()) {
      return _letterSeries(tier, rng);
    }
    return _shapeSeries(tier, rng);
  }

  /// A shape progression rendered as an actual diagram — sides increase
  /// by a constant step each figure (step 1 at tier 1-2: triangle, square,
  /// pentagon, ...; step 2 at tier 3-4: triangle, pentagon, heptagon, ...
  /// — a bigger jump to spot). Every option is itself a rendered polygon
  /// via `regularPolygonVertices`, not text.
  static Puzzle _shapeSeries(int tier, RngService rng) {
    final params = DifficultyCurve.paramsForTier(tier);
    final step = tier >= 3 ? 2 : 1;
    // Kept within triangle..decagon (3-10 sides) so every shape stays
    // easily distinguishable at a glance, even at the smallest option size.
    final maxStart = 10 - step * 3;
    final start = rng.nextInt(3, maxStart);
    final sideCounts = List.generate(3, (i) => start + step * i);
    final correctSides = start + step * 3;

    // Distractors: every other side count in triangle..decagon, shuffled
    // — simpler than hand-picking "near miss" values, and (unlike
    // clamping near-miss offsets to the valid range) never collapses to
    // fewer than 3 distinct options near either end of that range (e.g.
    // correctSides = 10, the decagon case, where several offset-based
    // candidates would otherwise all clamp down to the same couple of
    // values).
    final otherSides = [
      for (var s = 3; s <= 10; s++)
        if (s != correctSides) s,
    ];
    shuffleList(otherSides, rng);
    final distractorSides = otherSides.take(3).toList();

    final candidates = [
      (id: 'opt0', sides: correctSides),
      (id: 'opt1', sides: distractorSides[0]),
      (id: 'opt2', sides: distractorSides[1]),
      (id: 'opt3', sides: distractorSides[2]),
    ];
    shuffleList(candidates, rng);
    final correctId = candidates.firstWhere((c) => c.sides == correctSides).id;

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.figureSeries,
      questionText: 'The shapes below follow a pattern. Which shape comes '
          'next?',
      options: candidates.map((c) => c.id).toList(),
      correctAnswer: correctId,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      diagramData:
          DiagramData(kind: DiagramKind.shapeSequence, sideCounts: sideCounts),
      optionDiagrams: [
        for (final c in candidates)
          DiagramData(
            kind: DiagramKind.polygon,
            vertices: regularPolygonVertices(c.sides),
          ),
      ],
      hint: 'Each shape has $step more side${step == 1 ? '' : 's'} than the '
          'one before it.',
    );
  }

  static Puzzle _letterSeries(int tier, RngService rng) {
    final params = DifficultyCurve.paramsForTier(tier);
    final maxStep = tier >= 4 ? 5 : 4;
    final step = rng.nextInt(1, maxStep) * (rng.nextBool() ? 1 : -1);
    // Start position chosen so all 5 terms (0..4 steps from start) stay
    // within A-Z (codes 0-25).
    final span = step.abs() * 4;
    final startCode = step > 0 ? rng.nextInt(0, 25 - span) : rng.nextInt(span, 25);
    final codes = List.generate(5, (i) => startCode + step * i);
    final letters = codes.map((c) => String.fromCharCode(65 + c)).toList();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.figureSeries,
      questionText:
          '${letters.take(4).join(', ')}, ?  — find the next letter.',
      options: buildMcOptionsFromCandidates(
        letters[4],
        [
          for (final offset in [-2, -1, 1, 2, 3])
            String.fromCharCode(((codes[4] + offset) % 26 + 26) % 26 + 65),
        ],
        rng,
      ),
      correctAnswer: letters[4],
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: 'Find the constant letter-step between consecutive terms.',
    );
  }
}
