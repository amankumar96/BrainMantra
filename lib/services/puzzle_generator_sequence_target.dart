import 'dart:math' show pow;

import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'expression_evaluator.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// "2, 4, 6, 8, ?" — 4 terms of a generated sequence, asking for the 5th.
/// The correct answer always comes from literally applying the same rule
/// function one more step — never a separately-derived guess.
Puzzle generateSequence(int tier, RngService rng) {
  final params = DifficultyCurve.paramsForTier(tier);
  final useAdvanced = tier >= 3 && rng.nextBool();

  final List<int> terms;
  final int next;
  if (!useAdvanced) {
    final start = rng.nextInt(1, params.math.maxOperand);
    final step = rng.nextInt(1, (params.math.maxOperand ~/ 4).clamp(1, 20));
    terms = List.generate(4, (i) => start + i * step);
    next = start + 4 * step;
  } else if (rng.nextBool()) {
    // Widened ranges (not just the smallest plausible values) so this
    // branch has enough distinct outcomes to avoid accidental
    // question-text repeats within a handful of draws — a too-small pool
    // here previously caused a real (seed-independent-in-spirit, just
    // rare-but-real) anti-duplicate test flake during development.
    final start = rng.nextInt(1, 15);
    final ratio = rng.nextInt(2, 4);
    terms = List.generate(4, (i) => start * pow(ratio, i).toInt());
    next = start * pow(ratio, 4).toInt();
  } else {
    // Fibonacci-like: each term is the sum of the previous two.
    final first = rng.nextInt(1, 20);
    final second = rng.nextInt(1, 20);
    final third = first + second;
    final fourth = second + third;
    terms = [first, second, third, fourth];
    next = third + fourth;
  }

  return Puzzle(
    id: deterministicId(rng),
    category: PuzzleCategory.mathTest,
    type: PuzzleType.sequence,
    questionText: '${terms.join(", ")}, ?',
    options: buildNumericMcOptions(
      next,
      rng,
      spread: (params.math.maxOperand - params.math.minOperand).clamp(4, 40),
    ),
    correctAnswer: next,
    difficultyTier: tier,
    timeLimitSeconds: params.timeLimitSeconds,
  );
}

/// "Make 24 using 3, 4, 6, 8" (rendered as a full expression to evaluate,
/// e.g. "12 ÷ 3 + 5 = ?") — builds an expression string and runs it
/// through [evaluate] for the answer. This *is* the self-validation
/// ARCHITECTURE.md requires for this type: the evaluator, not separate
/// generator arithmetic, is the source of truth for the result.
Puzzle generateTargetNumber(int tier, RngService rng) {
  final params = DifficultyCurve.paramsForTier(tier);
  final canDivide = params.math.allowedOperators.contains(MathOperator.divide);
  final expression = canDivide && rng.nextBool()
      ? _buildDivisionExpression(params, rng)
      : _buildAddSubMulExpression(params, rng);

  final result = evaluate(expression);
  // Every branch below is engineered to produce a whole-number result, so
  // .round() is a safe, exact conversion — never a lossy guess.
  final correctAnswer = result.round();

  return Puzzle(
    id: deterministicId(rng),
    category: PuzzleCategory.mathTest,
    type: PuzzleType.targetNumber,
    questionText: '$expression = ?',
    options: buildNumericMcOptions(
      correctAnswer,
      rng,
      spread: (params.math.maxOperand - params.math.minOperand).clamp(4, 40),
    ),
    correctAnswer: correctAnswer,
    difficultyTier: tier,
    timeLimitSeconds: params.timeLimitSeconds,
  );
}

String _buildDivisionExpression(DifficultyParams params, RngService rng) {
  final divisor = rng.nextInt(2, 9);
  final lowerBound = params.math.minOperand.clamp(1, params.math.maxOperand);
  final quotient = rng.nextInt(lowerBound, params.math.maxOperand);
  final dividend = divisor * quotient;
  final extra = rng.nextInt(params.math.minOperand, params.math.maxOperand);
  if (rng.nextBool()) {
    return '$dividend ÷ $divisor + $extra';
  }
  final safeExtra = extra > quotient ? quotient : extra; // never go negative
  return '$dividend ÷ $divisor - $safeExtra';
}

String _buildAddSubMulExpression(DifficultyParams params, RngService rng) {
  final nonDivideOps =
      [MathOperator.add, MathOperator.subtract, MathOperator.multiply]
          .where(params.math.allowedOperators.contains)
          .toList();
  final termCount = rng.nextInt(2, 3);
  final buffer = StringBuffer();
  var running = rng.nextInt(params.math.minOperand, params.math.maxOperand);
  buffer.write(running);

  for (var i = 0; i < termCount; i++) {
    final op = nonDivideOps[rng.nextInt(0, nonDivideOps.length - 1)];
    final operand = rng.nextInt(params.math.minOperand, params.math.maxOperand);
    switch (op) {
      case MathOperator.add:
        buffer.write(' + $operand');
        running += operand;
      case MathOperator.subtract:
        final safeOperand = operand > running ? running : operand;
        buffer.write(' - $safeOperand');
        running -= safeOperand;
      case MathOperator.multiply:
        buffer.write(' × $operand');
        running *= operand;
      case MathOperator.divide:
        break; // excluded from nonDivideOps — unreachable
    }
  }
  return buffer.toString();
}
