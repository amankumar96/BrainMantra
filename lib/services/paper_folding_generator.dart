import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Paper Folding & Cutting (Phase 12 → Phase 14): a genuine
/// diagram-as-answer-option puzzle — the reference diagram shows the
/// folded sheet with its punch mark, and the 4 options are each a
/// rendered unfold pattern (a square with dots), not text. A vertical
/// fold mirrors a point across x=0.5; a horizontal fold mirrors it
/// across y=0.5 — applying whichever fold(s) are in play to the punch
/// point is what derives every hole position, never invented separately
/// from the fold sequence the question actually describes.
abstract final class PaperFoldingGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    // TUNABLE — a single fold at tier 1-2, both folds (a quarter-sheet
    // punch) at tier 3-4: twice as many resulting holes to track.
    final foldsVertical = tier >= 3 || rng.nextBool();
    final foldsHorizontal = tier >= 3 || !foldsVertical;

    // The punch point always lands within the folded (already-halved)
    // region for each axis actually folded, so it's physically
    // punchable through every layer.
    final px = foldsVertical ? _niceFraction(rng, max: 0.5) : _niceFraction(rng);
    final py =
        foldsHorizontal ? _niceFraction(rng, max: 0.5) : _niceFraction(rng);

    final correctHoles = _unfoldedHoles(px, py, foldsVertical, foldsHorizontal);

    final foldDescription = foldsVertical && foldsHorizontal
        ? 'in half vertically, then in half horizontally again'
        : foldsVertical
            ? 'in half vertically'
            : 'in half horizontally';

    // Distractors: forgetting one axis' mirror, over-mirroring both axes
    // even when only one fold applied, and a plausible-but-wrong single
    // hole with no mirroring at all — every one a real mistake a player
    // might actually make, not arbitrary noise. Exactly one of the three
    // (mirrorV, mirrorH) combos below always equals the *actual*
    // (foldsVertical, foldsHorizontal) — excluded by combo identity, not
    // by comparing the resulting List<double>s themselves (Dart's
    // default List equality is identity-based, not value-based, so
    // de-duplicating via a Set here would have silently let a distractor
    // share the exact same hole positions as the correct answer).
    final mirrorCombos = [(true, false), (false, true), (true, true)];
    final distractors = <List<double>>[
      [px, py], // no mirroring at all — always distinct (different length)
      for (final (mirrorV, mirrorH) in mirrorCombos)
        if (mirrorV != foldsVertical || mirrorH != foldsHorizontal)
          _unfoldedHoles(px, py, mirrorV, mirrorH),
    ];

    final candidates = [
      (id: 'opt0', holes: correctHoles),
      (id: 'opt1', holes: distractors[0]),
      (id: 'opt2', holes: distractors[1]),
      (id: 'opt3', holes: distractors[2]),
    ];
    shuffleList(candidates, rng);
    final correctId = candidates.firstWhere((c) => c.holes == correctHoles).id;

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.paperFolding,
      questionText: 'A square paper is folded $foldDescription. A hole is '
          'then punched through all the folded layers at the marked spot '
          '(below). Which pattern shows the holes when fully unfolded?',
      options: candidates.map((c) => c.id).toList(),
      correctAnswer: correctId,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      diagramData: DiagramData(kind: DiagramKind.dotGrid, points: [px, py]),
      optionDiagrams: [
        for (final c in candidates)
          DiagramData(kind: DiagramKind.dotGrid, points: c.holes),
      ],
      hint: 'Each fold mirrors the punch point across that fold\'s line — '
          'a vertical fold mirrors left-right, a horizontal fold '
          'mirrors top-bottom.',
    );
  }

  /// Every hole position the fully-unfolded sheet ends up with, given a
  /// single punch at ([px], [py]) and which axes were folded.
  static List<double> _unfoldedHoles(
    double px,
    double py,
    bool mirrorVertical,
    bool mirrorHorizontal,
  ) {
    final xs = mirrorVertical ? [px, 1 - px] : [px];
    final ys = mirrorHorizontal ? [py, 1 - py] : [py];
    return [for (final x in xs) for (final y in ys) ...[x, y]];
  }

  /// A punch position on a clean fraction (eighths) so every mirrored
  /// hole position is exact and visually distinct from the frame's edges
  /// — never a value that could land ambiguously close to 0, 0.5, or 1.
  static double _niceFraction(RngService rng, {double max = 1.0}) {
    const eighths = [1, 3, 5, 7]; // never exactly on an edge or the fold line
    final steps = eighths[rng.nextInt(0, eighths.length - 1)];
    return (steps / 8) * max;
  }
}
