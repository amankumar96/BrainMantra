import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Mirror & Water Images (Phase 12, reasoning topic 1) — the classic
/// letter-symmetry format real reasoning tests use for this topic when
/// not showing an actual rendered image: which letters look identical
/// under a vertical mirror (left-right flip) or a water/horizontal
/// mirror (top-bottom flip), plus the well-known b↔d / p↔q vertical
/// mirror pairs. A *true* rendered mirror-image question (flip an
/// arbitrary drawn figure) needs the diagram-as-answer-option
/// infrastructure this project's Stage 2 diagram work never built (see
/// ROADMAP_PHASE2.md's Phase 8) — this is the honest text-based
/// alternative, not a placeholder for it.
abstract final class MirrorImageGenerator {
  // TUNABLE — standard sets cited across reasoning-test prep material.
  static const _verticalSymmetric = [
    'A', 'H', 'I', 'M', 'O', 'T', 'U', 'V', 'W', 'X', 'Y',
  ];
  static const _verticalAsymmetric = [
    'B', 'C', 'D', 'E', 'F', 'G', 'J', 'K', 'L', 'N', 'P', 'Q', 'R', 'S', 'Z',
  ];
  static const _horizontalSymmetric = [
    'B', 'C', 'D', 'E', 'H', 'I', 'K', 'O', 'X',
  ];
  static const _horizontalAsymmetric = [
    'A', 'F', 'G', 'J', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'Y', 'Z',
  ];
  static const _mirrorPairs = {'b': 'd', 'd': 'b', 'p': 'q', 'q': 'p'};

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return switch (rng.nextInt(0, 2)) {
      0 => _sameUnderMirror(tier, params.timeLimitSeconds, rng, vertical: true),
      1 => _sameUnderMirror(tier, params.timeLimitSeconds, rng, vertical: false),
      _ => _pairLookup(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _sameUnderMirror(
    int tier,
    int timeLimitSeconds,
    RngService rng, {
    required bool vertical,
  }) {
    final symmetric = vertical ? _verticalSymmetric : _horizontalSymmetric;
    final asymmetric = vertical ? _verticalAsymmetric : _horizontalAsymmetric;
    final correct = symmetric[rng.nextInt(0, symmetric.length - 1)];
    final distractors = <String>{};
    while (distractors.length < 3) {
      distractors.add(asymmetric[rng.nextInt(0, asymmetric.length - 1)]);
    }
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.mirrorImage,
      questionText: vertical
          ? 'Which letter looks exactly the same in a mirror held '
              'upright beside it (a vertical mirror)?'
          : "Which letter looks exactly the same in a water/pond "
              'reflection below it (a horizontal mirror)?',
      options: buildMcOptionsFromCandidates(correct, distractors.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: vertical
          ? 'Letters with left-right symmetry look the same in a vertical mirror.'
          : 'Letters with top-bottom symmetry look the same in a water image.',
    );
  }

  static Puzzle _pairLookup(int tier, int timeLimitSeconds, RngService rng) {
    final letters = _mirrorPairs.keys.toList();
    final letter = letters[rng.nextInt(0, letters.length - 1)];
    final correct = _mirrorPairs[letter]!;
    final candidates = {'b', 'd', 'p', 'q'}..remove(correct);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.mirrorImage,
      questionText: "What is the mirror image of the letter '$letter' "
          '(vertical mirror)?',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: "'b' and 'd' mirror each other; so do 'p' and 'q'.",
    );
  }
}
