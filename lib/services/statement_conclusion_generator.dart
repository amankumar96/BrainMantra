import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Statement & Conclusion (Phase 12, reasoning topic 10): basic
/// syllogism validity — given two "All A are B" / "All B are C"
/// statements, does "All A are C" logically follow? True/False, using a
/// curated word bank so the syllogism is always genuinely valid or
/// genuinely invalid by construction (never ambiguous real-world
/// knowledge required).
abstract final class StatementConclusionGenerator {
  static const _triples = [
    ('Cats', 'Animals', 'Living things'),
    ('Roses', 'Flowers', 'Plants'),
    ('Doctors', 'Professionals', 'Educated people'),
    ('Squares', 'Rectangles', 'Quadrilaterals'),
    ('Mangoes', 'Fruits', 'Food items'),
    ('Cars', 'Vehicles', 'Machines'),
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final (a, b, c) = _triples[rng.nextInt(0, _triples.length - 1)];
    final isValid = rng.nextBool();

    final String statement1, statement2, conclusion;
    if (isValid) {
      // Classic valid chain: All A are B. All B are C. -> All A are C.
      statement1 = 'All $a are $b.';
      statement2 = 'All $b are $c.';
      conclusion = 'All $a are $c.';
    } else {
      // Classic invalid form: All A are C. All B are C. -> All A are B.
      // Sharing C doesn't make A and B the same set — a textbook
      // undistributed-middle fallacy, so this conclusion never follows.
      statement1 = 'All $a are $c.';
      statement2 = 'All $b are $c.';
      conclusion = 'All $a are $b.';
    }

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.statementConclusion,
      questionText: 'Statements: $statement1 $statement2\n'
          'Conclusion: $conclusion\nDoes the conclusion logically follow '
          'from the statements?',
      options: const ['True', 'False'],
      correctAnswer: isValid,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: '"All A are B, All B are C" validly gives "All A are C" — '
          'but sharing a third category does not link A and B directly.',
    );
  }
}
