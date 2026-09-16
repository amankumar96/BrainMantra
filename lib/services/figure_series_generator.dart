import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Figure Matrix & Series (Phase 12, reasoning topic 3) — built as a
/// **letter series** (A, C, E, G, ?), the standard textual analog to a
/// figure series real reasoning tests use interchangeably: same
/// "spot the pattern, extrapolate" skill, expressed as characters
/// instead of rendered shapes. A true rendered figure matrix needs the
/// diagram-as-answer-option infrastructure this project's Stage 2
/// diagram work never built (see ROADMAP_PHASE2.md's Phase 8) — this is
/// the honest text-based alternative, not a placeholder for it.
abstract final class FigureSeriesGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final maxStep = switch (tier) {
      1 => 2,
      2 => 3,
      3 => 4,
      _ => 5,
    };
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
