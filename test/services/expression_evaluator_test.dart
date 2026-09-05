import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/expression_evaluator.dart';

void main() {
  group('operator precedence and grouping', () {
    test('multiplication binds tighter than addition', () {
      expect(evaluate('3 + 4 × 2'), equals(11));
    });

    test('parentheses override normal precedence', () {
      expect(evaluate('(3 + 4) × 2'), equals(14));
    });

    test('nested parentheses evaluate correctly', () {
      expect(evaluate('((2 + 3) × (4 - 1))'), equals(15));
    });

    test('unary minus is supported', () {
      expect(evaluate('-5 + 10'), equals(5));
      expect(evaluate('-(3 + 2)'), equals(-5));
    });

    test('unicode operator glyphs (× ÷) work like their ASCII equivalents',
        () {
      expect(evaluate('10 ÷ 2 × 3'), equals(15));
    });

    test('plain ASCII operators also work', () {
      expect(evaluate('10 / 2 * 3'), equals(15));
    });
  });

  group('errors — thrown, never silently wrong', () {
    test('division by zero throws EvaluationException', () {
      expect(() => evaluate('5 ÷ 0'), throwsA(isA<EvaluationException>()));
    });

    test('division by zero inside a sub-expression also throws', () {
      expect(
        () => evaluate('1 + (5 / (3 - 3))'),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('unmatched opening parenthesis throws', () {
      expect(() => evaluate('(3 + 4'), throwsA(isA<EvaluationException>()));
    });

    test('trailing garbage after a valid expression throws', () {
      expect(() => evaluate('3 + 4)'), throwsA(isA<EvaluationException>()));
    });

    test('missing operand throws', () {
      expect(() => evaluate('3 + '), throwsA(isA<EvaluationException>()));
    });

    test('empty string throws', () {
      expect(() => evaluate(''), throwsA(isA<EvaluationException>()));
    });

    test('unrecognized character throws', () {
      expect(() => evaluate('3 + a'), throwsA(isA<EvaluationException>()));
    });

    test('two numbers with no operator between them throws', () {
      expect(() => evaluate('3 4'), throwsA(isA<EvaluationException>()));
    });
  });
}
