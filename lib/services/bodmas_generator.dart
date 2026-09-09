import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'expression_evaluator.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a BODMAS/order-of-operations question — e.g. "6 + 4 × (3 − 1) ÷
/// 2 = ?" — always evaluated by [evaluate] itself (never a hand-rolled
/// left-to-right calculation), so the answer is guaranteed to respect real
/// operator precedence, the same self-validation principle every other
/// generator in this codebase follows.
abstract final class BodmasGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final complexity = _complexityForTier(tier);

    // Retry on the rare case a randomly-built expression divides by zero
    // or lands on a non-whole result — regenerating is the normal path
    // here, not an error condition (mirrors _generateFamilyTree's retry
    // loop in puzzle_generator.dart).
    for (var attempt = 0; attempt < 30; attempt++) {
      final expression = _buildExpression(complexity, rng);
      try {
        final result = evaluate(expression);
        if (result != result.roundToDouble()) continue; // keep answers whole
        final correctAnswer = result.round();

        return Puzzle(
          id: deterministicId(rng),
          category: PuzzleCategory.mathTest,
          type: PuzzleType.bodmas,
          questionText: '$expression = ?',
          options: buildNumericMcOptions(correctAnswer, rng, spread: 10),
          correctAnswer: correctAnswer,
          difficultyTier: tier,
          timeLimitSeconds: params.timeLimitSeconds,
          hint: tier >= 3
              ? 'Order of operations: Brackets, Orders, Division/'
                  'Multiplication, Addition/Subtraction'
              : null,
        );
      } on EvaluationException {
        continue;
      }
    }
    throw StateError('Could not build a valid BODMAS expression (tier $tier)');
  }

  /// How many terms/operators the expression has, and whether it includes
  /// a bracket pair — TUNABLE, initial defaults. Tier 1: 2 terms, no
  /// brackets. Tier 4: 4 terms, always bracketed.
  static ({int termCount, bool useBrackets}) _complexityForTier(int tier) =>
      switch (tier) {
        1 => (termCount: 2, useBrackets: false),
        2 => (termCount: 3, useBrackets: false),
        3 => (termCount: 3, useBrackets: true),
        _ => (termCount: 4, useBrackets: true),
      };

  /// Builds an expression string like "6 + 4 × (3 − 1) ÷ 2" — small
  /// positive integer terms and, when requested, one bracketed adjacent
  /// pair (chosen at a random position, using whichever operator already
  /// sits between them) so the bracket placement varies rather than
  /// always landing in the same spot.
  static String _buildExpression(
    ({int termCount, bool useBrackets}) complexity,
    RngService rng,
  ) {
    const operators = ['+', '-', '×', '÷'];
    final terms = List.generate(complexity.termCount, (_) => rng.nextInt(1, 12));
    final ops = List.generate(
      complexity.termCount - 1,
      (_) => operators[rng.nextInt(0, operators.length - 1)],
    );

    // Which adjacent pair (i, i+1) to bracket, if at all — needs at least
    // 2 terms, always true here since termCount is never below 2. A
    // nullable int (not a -1 sentinel) deliberately, so "no bracket"
    // can never collide with a real index via `bracketAt + 1`.
    final int? bracketAt =
        complexity.useBrackets ? rng.nextInt(0, terms.length - 2) : null;

    final buffer = StringBuffer();
    for (var i = 0; i < terms.length; i++) {
      if (i == bracketAt) buffer.write('(');
      buffer.write(terms[i]);
      if (bracketAt != null && i == bracketAt + 1) buffer.write(')');
      if (i < ops.length) buffer.write(' ${ops[i]} ');
    }
    return buffer.toString();
  }
}
