import 'dart:math' show pow, sqrt;

import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/diagram_data.dart';
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

    case PuzzleType.bodmas:
      // Same " = ?" (4-char) suffix convention as targetNumber above —
      // evaluate() itself is the independent check here (a hand-rolled
      // left-to-right recompute in the test would just repeat whatever
      // precedence bug the generator might have).
      final expr =
          puzzle.questionText.substring(0, puzzle.questionText.length - 4);
      expect(evaluate(expr).round(), equals(puzzle.correctAnswer));

    case PuzzleType.speedDistance:
      final m = RegExp(r'Train A runs at (\d+) km/h, Train B at (\d+) km/h, '
              r'(in the same direction|in opposite directions)')
          .firstMatch(puzzle.questionText)!;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final sameDirection = m.group(3) == 'in the same direction';
      expect(sameDirection ? (a - b).abs() : a + b, equals(puzzle.correctAnswer));

    case PuzzleType.profitLoss:
      final m = RegExp(r'buys an item for ₹(\d+) and sells it for ₹(\d+)\. '
              r'Find the (profit|loss) %')
          .firstMatch(puzzle.questionText)!;
      final cp = int.parse(m.group(1)!);
      final sp = int.parse(m.group(2)!);
      final isProfit = m.group(3) == 'profit';
      final diff = isProfit ? sp - cp : cp - sp;
      expect((diff * 100 / cp).round(), equals(puzzle.correctAnswer));

    case PuzzleType.interest:
      final ci = RegExp(r'compound interest on ₹(\d+) at (\d+)% for (\d+) year')
          .firstMatch(puzzle.questionText);
      if (ci != null) {
        final p = int.parse(ci.group(1)!);
        final r = int.parse(ci.group(2)!);
        final t = int.parse(ci.group(3)!);
        final amount = p * pow(1 + r / 100, t);
        expect((amount - p).round(), equals(puzzle.correctAnswer));
      } else {
        final si = RegExp(r'simple interest on ₹(\d+) at (\d+)% for (\d+) year')
            .firstMatch(puzzle.questionText)!;
        final p = int.parse(si.group(1)!);
        final r = int.parse(si.group(2)!);
        final t = int.parse(si.group(3)!);
        expect((p * r * t) ~/ 100, equals(puzzle.correctAnswer));
      }

    case PuzzleType.perimeter:
      final rect = RegExp(
              r'that is (\d+) m long and (\d+) m wide. How many metres')
          .firstMatch(puzzle.questionText);
      final square = RegExp(r'sides of (\d+) cm').firstMatch(puzzle.questionText);
      final triangle = RegExp(
              r'sides measuring (\d+) m, (\d+) m and (\d+) m')
          .firstMatch(puzzle.questionText);
      if (rect != null) {
        final length = int.parse(rect.group(1)!);
        final width = int.parse(rect.group(2)!);
        expect(2 * (length + width), equals(puzzle.correctAnswer));
      } else if (square != null) {
        final side = int.parse(square.group(1)!);
        expect(4 * side, equals(puzzle.correctAnswer));
      } else {
        final m = triangle!;
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(2)!);
        final c = int.parse(m.group(3)!);
        expect(a + b + c, equals(puzzle.correctAnswer));
      }

    case PuzzleType.probability:
      int gcdCheck(int a, int b) => b == 0 ? a : gcdCheck(b, a % b);
      String reduce(int f, int t) {
        final g = gcdCheck(f, t);
        return '${f ~/ g}/${t ~/ g}';
      }

      final die = RegExp(r'rolling a number greater than (\d+)')
          .firstMatch(puzzle.questionText);
      final bag = RegExp(r'contains (\d+) red, (\d+) blue and (\d+) green')
          .firstMatch(puzzle.questionText);
      if (die != null) {
        final threshold = int.parse(die.group(1)!);
        expect(reduce(6 - threshold, 6), equals(puzzle.correctAnswer));
      } else if (bag != null) {
        final red = int.parse(bag.group(1)!);
        final blue = int.parse(bag.group(2)!);
        final green = int.parse(bag.group(3)!);
        expect(reduce(red, red + blue + green), equals(puzzle.correctAnswer));
      } else {
        final isHeart = puzzle.questionText.contains('a heart');
        expect(reduce(isHeart ? 13 : 12, 52), equals(puzzle.correctAnswer));
      }
      // Every option (correct answer included) must be a well-formed,
      // already-reduced fraction string — independent of how the
      // generator built it.
      for (final option in puzzle.options) {
        final parts = option.split('/');
        expect(parts, hasLength(2), reason: 'malformed fraction: $option');
        final f = int.parse(parts[0]);
        final t = int.parse(parts[1]);
        expect(gcdCheck(f, t), equals(1),
            reason: 'unreduced fraction option: $option');
      }

    case PuzzleType.ratio:
      final recipe = RegExp(r'for (\d+) people needs (\d+) cups of flour.+'
              r'for (\d+) people')
          .firstMatch(puzzle.questionText);
      final sharing = RegExp(r'₹(\d+) is shared between Ravi and Sita in '
              r'the ratio (\d+):(\d+)')
          .firstMatch(puzzle.questionText);
      final map = RegExp(r'1 cm represents (\d+) km.+?(\d+) cm apart')
          .firstMatch(puzzle.questionText);
      if (recipe != null) {
        final baseServes = int.parse(recipe.group(1)!);
        final baseCups = int.parse(recipe.group(2)!);
        final newServes = int.parse(recipe.group(3)!);
        expect(newServes % baseServes, equals(0),
            reason: 'scaling factor must be a clean integer');
        final factor = newServes ~/ baseServes;
        expect(baseCups * factor, equals(puzzle.correctAnswer));
      } else if (sharing != null) {
        final total = int.parse(sharing.group(1)!);
        final raviRatio = int.parse(sharing.group(2)!);
        final sitaRatio = int.parse(sharing.group(3)!);
        final unit = total ~/ (raviRatio + sitaRatio);
        expect(raviRatio * unit, equals(puzzle.correctAnswer));
      } else {
        final m = map!;
        final kmPerCm = int.parse(m.group(1)!);
        final mapDistanceCm = int.parse(m.group(2)!);
        expect(kmPerCm * mapDistanceCm, equals(puzzle.correctAnswer));
      }

    case PuzzleType.angleFinding:
      // Independently re-derives the third angle from the two *known*
      // angles parsed out of questionText (Angle Sum Property) — not by
      // reading diagramData.angles, which came from the same generator
      // call and so wouldn't actually catch a shared bug.
      final m = RegExp(r'are (\d+)° and (\d+)°').firstMatch(puzzle.questionText)!;
      final k0 = int.parse(m.group(1)!);
      final k1 = int.parse(m.group(2)!);
      expect(180 - k0 - k1, equals(puzzle.correctAnswer));
      expect(puzzle.diagramData?.kind, equals(DiagramKind.triangle));

    case PuzzleType.areaVolume:
      final rect = RegExp(r'rectangle with length (\d+) cm and width (\d+) cm')
          .firstMatch(puzzle.questionText);
      final cylinder = RegExp(
              r'cylinder with radius (\d+) cm and height (\d+) cm')
          .firstMatch(puzzle.questionText);
      if (rect != null) {
        final length = int.parse(rect.group(1)!);
        final width = int.parse(rect.group(2)!);
        expect(length * width, equals(puzzle.correctAnswer));
        expect(puzzle.diagramData?.kind, equals(DiagramKind.rectangle));
      } else if (cylinder != null) {
        final radius = int.parse(cylinder.group(1)!);
        final height = int.parse(cylinder.group(2)!);
        expect((3.141592653589793 * radius * radius * height).round(),
            equals(puzzle.correctAnswer));
        expect(puzzle.diagramData?.kind, equals(DiagramKind.cylinder));
      } else {
        final m = RegExp(r'circle with radius (\d+) cm')
            .firstMatch(puzzle.questionText)!;
        final radius = int.parse(m.group(1)!);
        expect((3.141592653589793 * radius * radius).round(),
            equals(puzzle.correctAnswer));
        expect(puzzle.diagramData?.kind, equals(DiagramKind.circle));
      }

    case PuzzleType.coordinateDistance:
      final m = RegExp(r'plotted at \((\d+), (\d+)\)')
          .firstMatch(puzzle.questionText)!;
      final x = int.parse(m.group(1)!);
      final y = int.parse(m.group(2)!);
      expect(sqrt(x * x + y * y).round(), equals(puzzle.correctAnswer));
      expect(puzzle.diagramData?.kind, equals(DiagramKind.coordinatePoint));

    case PuzzleType.graphReading:
      final data = puzzle.diagramData!;
      expect(data.kind, equals(DiagramKind.barGraph));
      final categories = data.categories!;
      final values = data.values!;
      if (puzzle.questionText.startsWith('Which category')) {
        final ranked = List.generate(values.length, (i) => i)
          ..sort((a, b) => values[b].compareTo(values[a]));
        final askSecond = puzzle.questionText.contains('second-highest');
        expect(categories[ranked[askSecond ? 1 : 0]],
            equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'category (\w) and category (\w)')
            .firstMatch(puzzle.questionText)!;
        final i = categories.indexOf(m.group(1)!);
        final j = categories.indexOf(m.group(2)!);
        expect((values[i] - values[j]).abs(), equals(puzzle.correctAnswer));
      }

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
          } else if (type == PuzzleType.graphReading) {
            // Option count is the bar count (3-5, tier-scaled) here, not
            // always 4 — every category is a genuine option, no filler
            // distractors needed.
            _checkWellFormedMc(puzzle);
          } else {
            expect(puzzle.options, hasLength(4));
            _checkWellFormedMc(puzzle);
          }
          _independentlyVerify(puzzle);

          // Hint rule (all-modes): null below tier 3, present at tier 3+
          // — except graphReading, which never has one (reading a graph
          // isn't formula-driven) and the pre-existing types, which never
          // populate hint at all.
          const hintedTypes = {
            PuzzleType.bodmas,
            PuzzleType.speedDistance,
            PuzzleType.profitLoss,
            PuzzleType.interest,
            PuzzleType.perimeter,
            PuzzleType.probability,
            PuzzleType.ratio,
            PuzzleType.angleFinding,
            PuzzleType.areaVolume,
            PuzzleType.coordinateDistance,
          };
          if (hintedTypes.contains(type)) {
            if (tier >= 3) {
              expect(puzzle.hint, isNotNull);
              expect(puzzle.hint, isNotEmpty);
            } else {
              expect(puzzle.hint, isNull);
            }
          } else {
            expect(puzzle.hint, isNull);
          }
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
    // shapeIdentification, coordinateDistance, graphReading, and
    // probability are deliberately excluded here. shapeIdentification/
    // coordinateDistance: small possibility spaces (16 texts; a handful of
    // Pythagorean triples × 2 for the x/y swap) that make a literal "10
    // draws, zero duplicates" check flaky by the birthday paradox.
    // graphReading: its "which category has the highest/second-highest
    // value?" question variant deliberately doesn't name a category in the
    // text (the answer itself is the category), so only 2 distinct texts
    // exist for that variant regardless of which values were actually
    // generated — real variety lives in diagramData/correctAnswer instead,
    // checked in graph_reading_generator_test.dart. probability: the die
    // sub-case alone has only 5 possible question texts (thresholds 1-5),
    // and it's a 1-in-3 pick each draw — the same birthday-paradox flake
    // risk, checked instead in probability_generator_test.dart. See
    // shape_reasoning_generator_test.dart for the same
    // dedicated-variety-check pattern.
    for (final type in PuzzleType.values.where(
      (t) =>
          t != PuzzleType.shapeIdentification &&
          t != PuzzleType.coordinateDistance &&
          t != PuzzleType.graphReading &&
          t != PuzzleType.probability,
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
