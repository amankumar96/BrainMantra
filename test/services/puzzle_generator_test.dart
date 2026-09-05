import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/puzzle.dart';
import 'package:math_blitz/services/expression_evaluator.dart';
import 'package:math_blitz/services/puzzle_generator.dart';
import 'package:math_blitz/services/rng_service.dart';

// A side-count table re-typed independently here (not imported from
// shape_reasoning_generator.dart), same rationale as
// shape_reasoning_generator_test.dart: a bug in the generator's own table
// should actually be caught, not just agreed with.
const _independentSideCounts = {
  'triangle': 3, 'square': 4, 'pentagon': 5, 'hexagon': 6,
  'heptagon': 7, 'octagon': 8, 'nonagon': 9, 'decagon': 10,
};

// Every relationship term the puzzle generator's distractor pool can ever
// produce (mirrors _relationshipVocabulary in puzzle_generator.dart, kept
// as a separate literal here rather than imported, so a typo in either
// list would actually surface as a test failure).
const _relationshipVocabulary = {
  'father', 'mother', 'son', 'daughter', 'brother', 'sister',
  'grandfather', 'grandmother', 'grandson', 'granddaughter',
  'uncle', 'aunt', 'nephew', 'niece', 'cousin', 'husband', 'wife',
  'father-in-law', 'mother-in-law', 'son-in-law', 'daughter-in-law',
  'brother-in-law', 'sister-in-law', 'great-grandfather',
  'great-grandmother', 'great-grandson', 'great-granddaughter',
  'grand-uncle', 'grand-aunt', 'grand-nephew', 'grand-niece',
};

/// Checks the invariants every multiple-choice puzzle must satisfy,
/// regardless of type: unique options, correct answer present among them.
void _checkWellFormedMc(Puzzle puzzle) {
  expect(puzzle.options.toSet().length, equals(puzzle.options.length),
      reason: 'duplicate option in ${puzzle.questionText}');
  expect(puzzle.options, contains(puzzle.correctAnswer.toString()),
      reason: 'correct answer missing from options in ${puzzle.questionText}');
}

/// Re-derives the correct answer independently of the generator, per type
/// — this is what actually catches a silent logic bug, not just a crash.
void _independentlyVerify(Puzzle puzzle) {
  switch (puzzle.type) {
    case PuzzleType.arithmetic:
      final m =
          RegExp(r'^(.+) (.) (.+) = \?$').firstMatch(puzzle.questionText)!;
      final expr = '${m.group(1)} ${m.group(2)} ${m.group(3)}';
      expect(evaluate(expr).round(), equals(puzzle.correctAnswer));

    case PuzzleType.trueFalse:
      final m = RegExp(r'^(.+) (.) (.+) = (-?\d+)$')
          .firstMatch(puzzle.questionText)!;
      final expr = '${m.group(1)} ${m.group(2)} ${m.group(3)}';
      final shown = int.parse(m.group(4)!);
      expect(evaluate(expr).round() == shown, equals(puzzle.correctAnswer));

    case PuzzleType.missingNumber:
      final blankA =
          RegExp(r'^\? (.) (.+) = (-?\d+)$').firstMatch(puzzle.questionText);
      final blankB = RegExp(r'^(.+) (.) \? = (-?\d+)$')
          .firstMatch(puzzle.questionText);
      final blankResult =
          RegExp(r'^(.+) (.) (.+) = \?$').firstMatch(puzzle.questionText);
      if (blankA != null) {
        // '? op b = result' -> solve algebraically for the blank operand,
        // independently of how the generator picked it.
        final op = blankA.group(1)!;
        final b = num.parse(blankA.group(2)!);
        final result = num.parse(blankA.group(3)!);
        final solved = switch (op) {
          '+' => result - b,
          '-' => result + b,
          '×' => result / b,
          _ => result * b, // ÷
        };
        expect(solved.round(), equals(puzzle.correctAnswer));
      } else if (blankB != null) {
        final a = num.parse(blankB.group(1)!);
        final op = blankB.group(2)!;
        final result = num.parse(blankB.group(3)!);
        final solved = switch (op) {
          '+' => result - a,
          '-' => a - result,
          '×' => result / a,
          _ => a / result, // ÷
        };
        expect(solved.round(), equals(puzzle.correctAnswer));
      } else {
        final m = blankResult!;
        expect(evaluate('${m.group(1)} ${m.group(2)} ${m.group(3)}').round(),
            equals(puzzle.correctAnswer));
      }

    case PuzzleType.oddOneOut:
      final values = puzzle.options.map(int.parse).toList();
      final oddValue = int.parse(puzzle.correctAnswer as String);
      final matching = values.where((v) => v != oddValue).toList();
      bool isPrime(int n) {
        if (n < 2) return false;
        for (var i = 2; i * i <= n; i++) {
          if (n % i == 0) return false;
        }
        return true;
      }
      bool isPerfectSquare(int n) {
        if (n < 0) return false;
        final r = _isqrtGuess(n);
        for (final candidate in [r - 1, r, r + 1]) {
          if (candidate >= 0 && candidate * candidate == n) return true;
        }
        return false;
      }
      final candidateRules = <bool Function(int)>[
        (n) => n % 2 == 0,
        (n) => n % 3 == 0,
        (n) => n % 5 == 0,
        isPerfectSquare,
        isPrime,
      ];
      final foundConsistentRule = candidateRules.any(
        (rule) => matching.every(rule) && !rule(oddValue),
      );
      expect(foundConsistentRule, isTrue,
          reason: 'no rule found where 3 options match and 1 does not: '
              '${puzzle.questionText}');

    case PuzzleType.sequence:
      final withoutTrailingQuestion =
          puzzle.questionText.substring(0, puzzle.questionText.length - 3);
      final terms =
          withoutTrailingQuestion.split(', ').map(int.parse).toList();
      expect(terms, hasLength(4));
      final diffs = [
        terms[1] - terms[0],
        terms[2] - terms[1],
        terms[3] - terms[2],
      ];
      final isArithmetic = diffs[0] == diffs[1] && diffs[1] == diffs[2];
      final isFibonacciLike =
          terms[2] == terms[0] + terms[1] && terms[3] == terms[1] + terms[2];
      final ratioOk = terms[0] != 0 &&
          terms[1] % terms[0] == 0 &&
          terms[2] == terms[1] * (terms[1] ~/ terms[0]) &&
          terms[3] == terms[2] * (terms[1] ~/ terms[0]);
      if (isArithmetic) {
        expect(terms[3] + diffs[0], equals(puzzle.correctAnswer));
      } else if (ratioOk) {
        final ratio = terms[1] ~/ terms[0];
        expect(terms[3] * ratio, equals(puzzle.correctAnswer));
      } else if (isFibonacciLike) {
        expect(terms[2] + terms[3], equals(puzzle.correctAnswer));
      } else {
        fail('sequence terms $terms match no known rule');
      }

    case PuzzleType.targetNumber:
      final expr =
          puzzle.questionText.substring(0, puzzle.questionText.length - 4);
      expect(evaluate(expr).round(), equals(puzzle.correctAnswer));

    case PuzzleType.familyTree:
      // The relationship-resolution algorithm itself is already
      // exhaustively tested against fixed fixtures in
      // relationship_resolver_test.dart, and tree structure in
      // family_tree_generator_test.dart — PuzzleGenerator doesn't expose
      // the tree it built internally, so at this wiring level we can only
      // sanity-check the assembled Puzzle, not re-run the resolver.
      expect(puzzle.correctAnswer, isA<String>());
      expect(_relationshipVocabulary.contains(puzzle.correctAnswer),
          isTrue, reason: 'unrecognized relationship term');
      expect(puzzle.questionText, contains('How is'));
      expect(puzzle.questionText, contains('related to'));

    case PuzzleType.shapeIdentification:
      if (puzzle.correctAnswer is int) {
        final shapeName = RegExp(r'a (\w+) have')
            .firstMatch(puzzle.questionText)!
            .group(1)!;
        expect(puzzle.correctAnswer,
            equals(_independentSideCounts[shapeName]));
      } else {
        final sides = int.parse(RegExp(r'has (\d+) sides')
            .firstMatch(puzzle.questionText)!
            .group(1)!);
        expect(_independentSideCounts[puzzle.correctAnswer as String],
            equals(sides));
      }
  }
}

int _isqrtGuess(int n) {
  var x = n;
  var y = (x + 1) ~/ 2;
  while (y < x) {
    x = y;
    y = (x + n ~/ x) ~/ 2;
  }
  return x;
}

void main() {
  for (final type in PuzzleType.values) {
    for (final tier in [1, 2, 3, 4]) {
      test('$type @ tier $tier: 500 generations, all well-formed and '
          'independently verified', () {
        for (var i = 0; i < 500; i++) {
          final puzzle = PuzzleGenerator.generate(
            tier: tier,
            type: type,
            rng: RngService.free(),
          );

          expect(puzzle.difficultyTier, equals(tier));
          if (type == PuzzleType.trueFalse) {
            expect(puzzle.options, equals(['True', 'False']));
          } else {
            expect(puzzle.options, hasLength(4));
            _checkWellFormedMc(puzzle);
          }
          _independentlyVerify(puzzle);
        }
      });
    }
  }

  group('determinism', () {
    for (final type in PuzzleType.values) {
      test('$type: same seeded RngService produces an identical puzzle '
          'twice', () {
        final a = PuzzleGenerator.generate(
          tier: 2,
          type: type,
          rng: RngService.seeded('puzzle-determinism-$type'),
        );
        final b = PuzzleGenerator.generate(
          tier: 2,
          type: type,
          rng: RngService.seeded('puzzle-determinism-$type'),
        );
        expect(a, equals(b));
      });
    }
  });

  group('anti-duplicate', () {
    // shapeIdentification is deliberately excluded here — its small
    // (16-text) possibility space makes a literal "10 draws, zero
    // duplicates" check flaky by the birthday paradox, not a sign of a
    // broken generator. See shape_reasoning_generator_test.dart for its
    // dedicated variety check instead.
    for (final type in PuzzleType.values.where(
      (t) => t != PuzzleType.shapeIdentification,
    )) {
      test('$type: 10 sequential generations have no duplicate '
          'questionText', () {
        final rng = RngService.seeded('anti-duplicate-$type');
        final texts = List.generate(
          10,
          (_) =>
              PuzzleGenerator.generate(tier: 3, type: type, rng: rng)
                  .questionText,
        );
        expect(texts.toSet().length, equals(texts.length));
      });
    }
  });
}
