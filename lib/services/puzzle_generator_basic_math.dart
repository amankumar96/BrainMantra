import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// The three math puzzle types that all boil down to "build one equation,
/// then ask about a piece of it" — arithmetic (ask for the result),
/// trueFalse (ask whether a shown result is right), and missingNumber
/// (ask for a blanked-out operand or result). Kept in one file since they
/// all share [_buildEquation] below.

/// "7 × 8 = ?" — ask for the result of a freshly-built equation.
Puzzle generateArithmetic(int tier, RngService rng) {
  final params = DifficultyCurve.paramsForTier(tier);
  final equation = _buildEquation(_pickOperator(params, rng), params, rng);
  return Puzzle(
    id: deterministicId(rng),
    category: PuzzleCategory.mathTest,
    type: PuzzleType.arithmetic,
    questionText: '${equation.a} ${equation.symbol} ${equation.b} = ?',
    options: buildNumericMcOptions(
      equation.result,
      rng,
      spread: _distractorSpread(params),
    ),
    correctAnswer: equation.result,
    difficultyTier: tier,
    timeLimitSeconds: params.timeLimitSeconds,
  );
}

/// "9 + 10 = 21" — ask whether a shown equation is true or false. Built by
/// taking a genuinely true equation and, half the time, deliberately
/// corrupting the shown result by a small nonzero amount.
Puzzle generateTrueFalse(int tier, RngService rng) {
  final params = DifficultyCurve.paramsForTier(tier);
  final equation = _buildEquation(_pickOperator(params, rng), params, rng);

  final showTrue = rng.nextBool();
  var shownResult = equation.result;
  if (!showTrue) {
    // A small, always-nonzero delta (magnitude 1-3, either sign) — never
    // 0, so the "false" equation is guaranteed to actually be false.
    final magnitude = rng.nextInt(1, 3);
    final sign = rng.nextBool() ? 1 : -1;
    shownResult = equation.result + magnitude * sign;
  }

  return Puzzle(
    id: deterministicId(rng),
    category: PuzzleCategory.mathTest,
    type: PuzzleType.trueFalse,
    questionText:
        '${equation.a} ${equation.symbol} ${equation.b} = $shownResult',
    options: const ['True', 'False'],
    correctAnswer: showTrue,
    difficultyTier: tier,
    timeLimitSeconds: params.timeLimitSeconds,
  );
}

/// "12 + ? = 20" — ask for one blanked-out piece (either operand, or the
/// result) of a freshly-built equation. No algebra needed to find the
/// answer: the blanked value is already known, since it's the same value
/// used to construct the equation in the first place.
Puzzle generateMissingNumber(int tier, RngService rng) {
  final params = DifficultyCurve.paramsForTier(tier);
  final equation = _buildEquation(_pickOperator(params, rng), params, rng);

  // 0 = blank the first operand, 1 = blank the second, 2 = blank the result.
  final blankSlot = rng.nextInt(0, 2);
  final int correctAnswer;
  final String questionText;
  switch (blankSlot) {
    case 0:
      correctAnswer = equation.a;
      questionText = '? ${equation.symbol} ${equation.b} = ${equation.result}';
    case 1:
      correctAnswer = equation.b;
      questionText = '${equation.a} ${equation.symbol} ? = ${equation.result}';
    default:
      correctAnswer = equation.result;
      questionText = '${equation.a} ${equation.symbol} ${equation.b} = ?';
  }

  return Puzzle(
    id: deterministicId(rng),
    category: PuzzleCategory.mathTest,
    type: PuzzleType.missingNumber,
    questionText: questionText,
    options: buildNumericMcOptions(
      correctAnswer,
      rng,
      spread: _distractorSpread(params),
    ),
    correctAnswer: correctAnswer,
    difficultyTier: tier,
    timeLimitSeconds: params.timeLimitSeconds,
  );
}

/// Picks one of the tier's allowed operators at random.
MathOperator _pickOperator(DifficultyParams params, RngService rng) {
  final operators = params.math.allowedOperators;
  return operators[rng.nextInt(0, operators.length - 1)];
}

/// How far from the correct answer distractor options should be drawn —
/// scales with the tier's operand range, so higher tiers (bigger numbers)
/// get plausibly-wrong distractors instead of ones that are obviously too
/// close or too far off.
int _distractorSpread(DifficultyParams params) =>
    (params.math.maxOperand - params.math.minOperand).clamp(4, 40);

/// One freshly-built, always-correct equation: `a <symbol> b = result`.
///
/// Every operator is constructed so the result is guaranteed valid without
/// ever having to generate-then-check: subtraction always swaps operands
/// so the result is never negative, and division is built *backward* —
/// picking the divisor and quotient first, then multiplying them to get a
/// dividend that's guaranteed to divide evenly.
({int a, int b, int result, String symbol}) _buildEquation(
  MathOperator operator,
  DifficultyParams params,
  RngService rng,
) {
  final min = params.math.minOperand;
  final max = params.math.maxOperand;
  switch (operator) {
    case MathOperator.add:
      final a = rng.nextInt(min, max);
      final b = rng.nextInt(min, max);
      return (a: a, b: b, result: a + b, symbol: '+');
    case MathOperator.subtract:
      final x = rng.nextInt(min, max);
      final y = rng.nextInt(min, max);
      final a = x >= y ? x : y;
      final b = x >= y ? y : x;
      return (a: a, b: b, result: a - b, symbol: '-');
    case MathOperator.multiply:
      final a = rng.nextInt(min, max);
      final b = rng.nextInt(min, max);
      return (a: a, b: b, result: a * b, symbol: '×');
    case MathOperator.divide:
      final lowerBound = min < 1 ? 1 : min;
      final divisor = rng.nextInt(lowerBound, max);
      final quotient = rng.nextInt(lowerBound, max);
      return (a: divisor * quotient, b: divisor, result: quotient, symbol: '÷');
  }
}
