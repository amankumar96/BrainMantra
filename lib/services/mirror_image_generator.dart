import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Mirror & Water Images (Phase 12 → Phase 13): a genuine
/// diagram-as-answer-option puzzle — a reference shape is drawn once
/// (`Puzzle.diagramData`), and the 4 answer options are themselves small
/// rendered shapes (`Puzzle.optionDiagrams`), not text. Every shape is a
/// hand-picked asymmetric polygon (so a flip is actually visually
/// consequential) transformed by simple coordinate-flip arithmetic —
/// never hardcoded per-option, always derived from the same reference
/// vertices the question shows.
///
/// "Mirror image" = reflection across a vertical axis (x, y) → (−x, y),
/// as if standing a mirror upright beside the shape. "Water image" =
/// reflection across a horizontal axis (x, y) → (x, −y), as if looking at
/// the shape's reflection in water below it.
abstract final class MirrorImageGenerator {
  // TUNABLE — hand-picked asymmetric polygons (simple, non-self-
  // intersecting) so every flip is visually distinct from the original
  // and from the other flip axis. Flattened [x0,y0,x1,y1,...] unit
  // coordinates — DiagramPainter.polygonPoints fits these to whatever box
  // they're actually drawn in, so the exact scale here doesn't matter.
  // Template 2 was originally [0,0.6, 1.2,0.6, 1.2,0, 2,1, 1.2,2, 1.2,1.4,
  // 0,1.4] (an arrow) — a real bug caught from a device screenshot showing
  // two visually-identical option pairs: that shape is exactly symmetric
  // about its own horizontal centerline (every (x,y) has a matching
  // (x, 2-y) elsewhere in the list), so flipV rendered identically to the
  // original, and rotate180 rendered identically to flipH — 2 of the 4
  // options always collapsed into indistinguishable duplicate pairs,
  // regardless of which one the generator considered "correct". Fixed by
  // nudging the final vertex ((0,1.4) → (0.2,1.5)) to break that
  // symmetry while keeping the shape simple and non-self-intersecting.
  static const _templates = [
    [0.0, 0.0, 0.0, 3.0, 2.0, 2.0, 2.0, 1.3, 0.7, 1.3, 0.7, 0.0],
    [0.0, 0.0, 0.0, 2.0, 1.0, 2.0, 1.0, 1.0, 2.0, 1.0, 2.0, 0.0],
    [0.0, 0.6, 1.2, 0.6, 1.2, 0.0, 2.0, 1.0, 1.2, 2.0, 1.2, 1.4, 0.2, 1.5],
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final template = _templates[rng.nextInt(0, _templates.length - 1)];
    final askMirror = rng.nextBool(); // false => water image instead

    final original = template;
    final flipH = _flipH(template);
    final flipV = _flipV(template);
    final rotated = _rotate180(template);
    final correctShape = askMirror ? flipH : flipV;
    final wrongAxisShape = askMirror ? flipV : flipH;

    // (id, vertices) pairs, shuffled together so the correct answer's
    // grid position is random but every id stays paired with its own
    // shape.
    final candidates = [
      (id: 'opt0', vertices: correctShape),
      (id: 'opt1', vertices: original),
      (id: 'opt2', vertices: wrongAxisShape),
      (id: 'opt3', vertices: rotated),
    ];
    shuffleList(candidates, rng);
    final correctId = candidates
        .firstWhere((c) => c.vertices == correctShape)
        .id;

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.mirrorImage,
      questionText: askMirror
          ? 'Which figure is the MIRROR image (reflected left-right) of '
                'the shape shown above?'
          : 'Which figure is the WATER image (reflected upside-down) of '
                'the shape shown above?',
      options: candidates.map((c) => c.id).toList(),
      correctAnswer: correctId,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      diagramData: DiagramData(kind: DiagramKind.polygon, vertices: original),
      optionDiagrams: [
        for (final c in candidates)
          DiagramData(kind: DiagramKind.polygon, vertices: c.vertices),
      ],
      hint: askMirror
          ? 'A mirror image flips the shape left-right, like standing a '
                'mirror upright beside it.'
          : 'A water image flips the shape upside-down, like its '
                "reflection in water below it.",
    );
  }

  static List<double> _flipH(List<double> v) => [
    for (var i = 0; i < v.length; i += 2) ...[-v[i], v[i + 1]],
  ];

  static List<double> _flipV(List<double> v) => [
    for (var i = 0; i < v.length; i += 2) ...[v[i], -v[i + 1]],
  ];

  static List<double> _rotate180(List<double> v) => [
    for (var i = 0; i < v.length; i += 2) ...[-v[i], -v[i + 1]],
  ];
}
