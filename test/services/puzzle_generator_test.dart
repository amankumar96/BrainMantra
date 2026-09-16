import 'dart:math' show pow, sqrt;

import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/diagram_data.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/services/expression_evaluator.dart';
import 'package:brain_mantra/services/puzzle_generator.dart';
import 'package:brain_mantra/services/rng_service.dart';

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

    case PuzzleType.numberClassification:
      final prime = RegExp(r'Is (\d+) a prime number\?')
          .firstMatch(puzzle.questionText);
      if (prime != null) {
        final n = int.parse(prime.group(1)!);
        bool isPrime(int n) {
          if (n < 2) return false;
          for (var i = 2; i * i <= n; i++) {
            if (n % i == 0) return false;
          }
          return true;
        }
        expect(isPrime(n), equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'smallest number set that (-?\d+) belongs to')
            .firstMatch(puzzle.questionText)!;
        final n = int.parse(m.group(1)!);
        final expected = n < 0
            ? 'Integer (Z)'
            : n == 0
                ? 'Whole number (W)'
                : 'Natural number (N)';
        expect(expected, equals(puzzle.correctAnswer));
      }

    case PuzzleType.surds:
      final product =
          RegExp(r'√(\d+) × √(\d+) = √\?').firstMatch(puzzle.questionText);
      if (product != null) {
        final a = int.parse(product.group(1)!);
        final b = int.parse(product.group(2)!);
        expect(a * b, equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'Simplify √(\d+) to the form k√m')
            .firstMatch(puzzle.questionText)!;
        final n = int.parse(m.group(1)!);
        final answerMatch =
            RegExp(r'^(\d+)√(\d+)$').firstMatch(puzzle.correctAnswer as String)!;
        final k = int.parse(answerMatch.group(1)!);
        final mVal = int.parse(answerMatch.group(2)!);
        expect(k * k * mVal, equals(n));
      }

    case PuzzleType.algebraicIdentity:
      final xa = RegExp(r'x=(-?\d+), a=(-?\d+)').firstMatch(puzzle.questionText)!;
      final x = int.parse(xa.group(1)!);
      final a = int.parse(xa.group(2)!);
      final expected = puzzle.questionText.contains('(x+a)(x-a)')
          ? x * x - a * a
          : puzzle.questionText.contains('(x-a)² = x²')
              ? x * x - 2 * x * a + a * a
              : x * x + 2 * x * a + a * a; // (x+a)² and the (x+a)(x+a) case
      expect(expected, equals(puzzle.correctAnswer));

    case PuzzleType.linearEquation:
      final pair = RegExp(r'(-?\d+)x \+ (-?\d+)y = (-?\d+) and '
              r'(-?\d+)x \+ (-?\d+)y = (-?\d+)')
          .firstMatch(puzzle.questionText);
      if (pair != null) {
        final a1 = int.parse(pair.group(1)!);
        final b1 = int.parse(pair.group(2)!);
        final c1 = int.parse(pair.group(3)!);
        final a2 = int.parse(pair.group(4)!);
        final b2 = int.parse(pair.group(5)!);
        final c2 = int.parse(pair.group(6)!);
        final denominator = a1 * b2 - a2 * b1;
        final x = (c1 * b2 - c2 * b1) / denominator;
        expect(x.round(), equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'Solve for x: (-?\d+)x ([+-]) (\d+) = 0')
            .firstMatch(puzzle.questionText)!;
        final a = int.parse(m.group(1)!);
        final sign = m.group(2)!;
        final bAbs = int.parse(m.group(3)!);
        final b = sign == '+' ? bAbs : -bAbs;
        expect(-b ~/ a, equals(puzzle.correctAnswer));
      }

    case PuzzleType.quadraticEquation:
      final vieta = RegExp(r'For x² ([+-]) (\d+)x ([+-]) (\d+) = 0, find the '
              r'(sum|product) of the roots')
          .firstMatch(puzzle.questionText);
      if (vieta != null) {
        final b = vieta.group(1) == '+'
            ? int.parse(vieta.group(2)!)
            : -int.parse(vieta.group(2)!);
        final c = vieta.group(3) == '+'
            ? int.parse(vieta.group(4)!)
            : -int.parse(vieta.group(4)!);
        final wantsSum = vieta.group(5) == 'sum';
        expect(wantsSum ? -b : c, equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'does (-?\d+)x² ([+-]) (\d+)x ([+-]) (\d+) = 0 have')
            .firstMatch(puzzle.questionText)!;
        final a = int.parse(m.group(1)!);
        final b =
            m.group(2) == '+' ? int.parse(m.group(3)!) : -int.parse(m.group(3)!);
        final c =
            m.group(4) == '+' ? int.parse(m.group(5)!) : -int.parse(m.group(5)!);
        final d = b * b - 4 * a * c;
        final expected = d > 0
            ? '2 distinct real roots'
            : d == 0
                ? '1 repeated real root'
                : 'No real roots';
        expect(expected, equals(puzzle.correctAnswer));
      }

    case PuzzleType.progression:
      if (puzzle.questionText.contains('sum of its first')) {
        final m = RegExp(r'starts at (\d+) with common difference (\d+).+'
                r'first (\d+) terms')
            .firstMatch(puzzle.questionText)!;
        final a = int.parse(m.group(1)!);
        final d = int.parse(m.group(2)!);
        final n = int.parse(m.group(3)!);
        expect((n ~/ 2) * (2 * a + (n - 1) * d), equals(puzzle.correctAnswer));
      } else if (puzzle.questionText.contains('AP starts')) {
        final m = RegExp(r'starts at (\d+) with common difference (\d+).+'
                r'its (\d+)th term')
            .firstMatch(puzzle.questionText)!;
        final a = int.parse(m.group(1)!);
        final d = int.parse(m.group(2)!);
        final n = int.parse(m.group(3)!);
        expect(a + (n - 1) * d, equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'GP starts at (\d+) with common ratio (\d+).+'
                r'its (\d+)th term')
            .firstMatch(puzzle.questionText)!;
        final a = int.parse(m.group(1)!);
        final r = int.parse(m.group(2)!);
        final n = int.parse(m.group(3)!);
        var expected = a;
        for (var i = 1; i < n; i++) {
          expected *= r;
        }
        expect(expected, equals(puzzle.correctAnswer));
      }

    case PuzzleType.trigRatio:
      const standardTable = {
        '0': {'sin': '0', 'cos': '1', 'tan': '0'},
        '30': {'sin': '1/2', 'cos': '√3/2', 'tan': '1/√3'},
        '45': {'sin': '1/√2', 'cos': '1/√2', 'tan': '1'},
        '60': {'sin': '√3/2', 'cos': '1/2', 'tan': '√3'},
        '90': {'sin': '1', 'cos': '0'},
      };
      final lookup =
          RegExp(r'What is (sin|cos|tan)\((\d+)°\)\?').firstMatch(puzzle.questionText);
      final doubleAngle = RegExp(
              r'sinθ = (\d+)/(\d+) and cosθ = (\d+)/(\d+).+sin2θ')
          .firstMatch(puzzle.questionText);
      if (lookup != null) {
        final expected = standardTable[lookup.group(2)!]![lookup.group(1)!];
        expect(expected, equals(puzzle.correctAnswer));
      } else if (doubleAngle != null) {
        final opp = int.parse(doubleAngle.group(1)!);
        final hyp = int.parse(doubleAngle.group(2)!);
        final adj = int.parse(doubleAngle.group(3)!);
        final num = 2 * opp * adj;
        final den = hyp * hyp;
        final g = _gcd(num, den);
        expect('${num ~/ g}/${den ~/ g}', equals(puzzle.correctAnswer));
      } else {
        final m = RegExp(r'(sinθ|cosθ) = (\d+)/(\d+)').firstMatch(puzzle.questionText)!;
        final givenNum = int.parse(m.group(2)!);
        final hyp = int.parse(m.group(3)!);
        final answerParts =
            (puzzle.correctAnswer as String).split('/').map(int.parse).toList();
        // sin²θ + cos²θ = 1  ->  givenNum² + answerNum² = hyp²  (both over
        // the same hyp, checked purely algebraically here).
        expect(givenNum * givenNum + answerParts[0] * answerParts[0],
            equals(hyp * hyp));
        expect(answerParts[1], equals(hyp));
      }

    case PuzzleType.mensurationAdvanced:
      const piLiteral = 3.141592653589793;
      final sphere = RegExp(r'(volume|surface area) of a sphere with radius '
              r'(\d+) cm')
          .firstMatch(puzzle.questionText);
      final cone = RegExp(r'volume of a cone with radius (\d+) cm and height '
              r'(\d+) cm');
      final coneCsa = RegExp(r'curved surface area of a cone with radius '
          r'(\d+) cm and slant height (\d+) cm');
      final hemisphere = RegExp(r'(volume|curved surface area|total surface '
              r'area) of a hemisphere with radius (\d+) cm')
          .firstMatch(puzzle.questionText);
      final heron = RegExp(r"Heron's formula, find the area of a triangle "
              r'with sides (\d+) cm, (\d+) cm, and (\d+) cm')
          .firstMatch(puzzle.questionText);
      final rhombus = RegExp(r'rhombus with diagonals (\d+) cm and (\d+) cm')
          .firstMatch(puzzle.questionText);
      if (sphere != null) {
        final r = int.parse(sphere.group(2)!);
        final expected = sphere.group(1) == 'volume'
            ? (4 / 3) * piLiteral * r * r * r
            : 4 * piLiteral * r * r;
        expect(expected.round(), equals(puzzle.correctAnswer));
      } else if (cone.hasMatch(puzzle.questionText)) {
        final m = cone.firstMatch(puzzle.questionText)!;
        final r = int.parse(m.group(1)!);
        final h = int.parse(m.group(2)!);
        expect(((1 / 3) * piLiteral * r * r * h).round(),
            equals(puzzle.correctAnswer));
      } else if (coneCsa.hasMatch(puzzle.questionText)) {
        final m = coneCsa.firstMatch(puzzle.questionText)!;
        final r = int.parse(m.group(1)!);
        final l = int.parse(m.group(2)!);
        expect((piLiteral * r * l).round(), equals(puzzle.correctAnswer));
      } else if (hemisphere != null) {
        final r = int.parse(hemisphere.group(2)!);
        final expected = switch (hemisphere.group(1)) {
          'volume' => (2 / 3) * piLiteral * r * r * r,
          'curved surface area' => 2 * piLiteral * r * r,
          _ => 3 * piLiteral * r * r,
        };
        expect(expected.round(), equals(puzzle.correctAnswer));
      } else if (heron != null) {
        final a = int.parse(heron.group(1)!);
        final b = int.parse(heron.group(2)!);
        final c = int.parse(heron.group(3)!);
        final s = (a + b + c) / 2;
        final area = sqrt(s * (s - a) * (s - b) * (s - c));
        expect(area.round(), equals(puzzle.correctAnswer));
      } else {
        final m = rhombus!;
        final d1 = int.parse(m.group(1)!);
        final d2 = int.parse(m.group(2)!);
        expect((d1 * d2) ~/ 2, equals(puzzle.correctAnswer));
      }

    case PuzzleType.coordinateGeometry:
      final slope = RegExp(r'slope of the line through \((-?\d+), (-?\d+)\) '
              r'and \((-?\d+), (-?\d+)\)')
          .firstMatch(puzzle.questionText);
      final midpoint = RegExp(r'(x|y)-coordinate of the midpoint of '
              r'\((-?\d+), (-?\d+)\) and \((-?\d+), (-?\d+)\)')
          .firstMatch(puzzle.questionText);
      final triangle = RegExp(r'vertices \((-?\d+), (-?\d+)\), '
              r'\((-?\d+), (-?\d+)\), \((-?\d+), (-?\d+)\)')
          .firstMatch(puzzle.questionText);
      final perpendicular =
          RegExp(r'line has slope (-?\d+)').firstMatch(puzzle.questionText);
      if (slope != null) {
        final x1 = int.parse(slope.group(1)!);
        final y1 = int.parse(slope.group(2)!);
        final x2 = int.parse(slope.group(3)!);
        final y2 = int.parse(slope.group(4)!);
        final m = puzzle.correctAnswer as int;
        expect(y2 - y1, equals(m * (x2 - x1)));
      } else if (midpoint != null) {
        final wantsX = midpoint.group(1) == 'x';
        final x1 = int.parse(midpoint.group(2)!);
        final y1 = int.parse(midpoint.group(3)!);
        final x2 = int.parse(midpoint.group(4)!);
        final y2 = int.parse(midpoint.group(5)!);
        final expected = wantsX ? x1 + x2 : y1 + y2;
        expect(expected, equals(2 * (puzzle.correctAnswer as int)));
      } else if (triangle != null) {
        final coords = List.generate(6, (i) => int.parse(triangle.group(i + 1)!));
        final area2 = coords[0] * (coords[3] - coords[5]) +
            coords[2] * (coords[5] - coords[1]) +
            coords[4] * (coords[1] - coords[3]);
        expect(area2.abs(), equals(puzzle.correctAnswer));
      } else {
        final m = int.parse(perpendicular!.group(1)!);
        final parts =
            (puzzle.correctAnswer as String).split('/').map(int.parse).toList();
        expect(m * parts[0], equals(-parts[1]));
      }

    case PuzzleType.logarithm:
      final m = RegExp(r'logₐx = (\d+) and logₐy = (\d+)').firstMatch(puzzle.questionText)!;
      final logX = int.parse(m.group(1)!);
      final logY = int.parse(m.group(2)!);
      final expected =
          puzzle.questionText.contains('logₐ(xy)') ? logX + logY : logX - logY;
      expect(expected, equals(puzzle.correctAnswer));

    case PuzzleType.permutationCombination:
      final m = RegExp(r'(ⁿPᵣ|ⁿCᵣ) for n=(\d+), r=(\d+)').firstMatch(puzzle.questionText)!;
      final n = int.parse(m.group(2)!);
      final r = int.parse(m.group(3)!);
      final nPr = _factorial(n) ~/ _factorial(n - r);
      final expected = m.group(1) == 'ⁿPᵣ' ? nPr : nPr ~/ _factorial(r);
      expect(expected, equals(puzzle.correctAnswer));

    case PuzzleType.statistics:
      final valuesMatch =
          RegExp(r'of: (.+)$').firstMatch(puzzle.questionText)!;
      final values =
          valuesMatch.group(1)!.split(', ').map(int.parse).toList();
      if (puzzle.questionText.contains('mean')) {
        expect(values.reduce((a, b) => a + b),
            equals((puzzle.correctAnswer as int) * values.length));
      } else if (puzzle.questionText.contains('median')) {
        final sorted = List.of(values)..sort();
        expect(sorted[sorted.length ~/ 2], equals(puzzle.correctAnswer));
      } else if (puzzle.questionText.contains('mode')) {
        final counts = <int, int>{};
        for (final v in values) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
        final expected =
            counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        expect(expected, equals(puzzle.correctAnswer));
      } else if (puzzle.questionText.contains('range')) {
        expect(
          values.reduce((a, b) => a > b ? a : b) -
              values.reduce((a, b) => a < b ? a : b),
          equals(puzzle.correctAnswer),
        );
      } else {
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance =
            values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
                values.length;
        expect(variance.round(), equals(puzzle.correctAnswer));
      }

    case PuzzleType.unitConversion:
      final km = RegExp(r'Convert (\d+) km to metres').firstMatch(puzzle.questionText);
      final mToKm = RegExp(r'Convert (\d+) m to kilometres').firstMatch(puzzle.questionText);
      final kg = RegExp(r'Convert (\d+) kg to grams').firstMatch(puzzle.questionText);
      final gToKg = RegExp(r'Convert (\d+) g to kilograms').firstMatch(puzzle.questionText);
      final hours = RegExp(r'Convert (\d+) hours to minutes').firstMatch(puzzle.questionText);
      final minToHours =
          RegExp(r'Convert (\d+) minutes to hours').firstMatch(puzzle.questionText);
      final percent =
          RegExp(r'Express (\d+)% as a ratio').firstMatch(puzzle.questionText);
      if (km != null) {
        expect(int.parse(km.group(1)!) * 1000, equals(puzzle.correctAnswer));
      } else if (mToKm != null) {
        expect(int.parse(mToKm.group(1)!) ~/ 1000, equals(puzzle.correctAnswer));
      } else if (kg != null) {
        expect(int.parse(kg.group(1)!) * 1000, equals(puzzle.correctAnswer));
      } else if (gToKg != null) {
        expect(int.parse(gToKg.group(1)!) ~/ 1000, equals(puzzle.correctAnswer));
      } else if (hours != null) {
        expect(int.parse(hours.group(1)!) * 60, equals(puzzle.correctAnswer));
      } else if (minToHours != null) {
        expect(int.parse(minToHours.group(1)!) ~/ 60, equals(puzzle.correctAnswer));
      } else {
        final p = int.parse(percent!.group(1)!);
        final g = _gcd(p, 100);
        expect('${p ~/ g}:${100 ~/ g}', equals(puzzle.correctAnswer));
      }

    case PuzzleType.workTime:
      final work = RegExp(r'finish a job in (\d+) days, B can finish the '
              r'same job in (\d+) days')
          .firstMatch(puzzle.questionText);
      if (work != null) {
        final a = int.parse(work.group(1)!);
        final b = int.parse(work.group(2)!);
        expect(a * b, equals((puzzle.correctAnswer as int) * (a + b)));
      } else {
        final m = RegExp(r'fills a tank in (\d+) hours\. Pipe B empties the '
                r'same tank in (\d+) hours')
            .firstMatch(puzzle.questionText)!;
        final fill = int.parse(m.group(1)!);
        final empty = int.parse(m.group(2)!);
        expect(fill * empty, equals((puzzle.correctAnswer as int) * (empty - fill)));
      }

    case PuzzleType.mixtureAlligation:
      final m = RegExp(r'tea worth ₹(\d+)/kg with tea worth ₹(\d+)/kg to get '
              r'a mixture worth ₹(\d+)/kg')
          .firstMatch(puzzle.questionText)!;
      final cheap = int.parse(m.group(1)!);
      final dear = int.parse(m.group(2)!);
      final mean = int.parse(m.group(3)!);
      final g = _gcd(dear - mean, mean - cheap);
      expect(
        '${(dear - mean) ~/ g}:${(mean - cheap) ~/ g}',
        equals(puzzle.correctAnswer),
      );

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

    case PuzzleType.mirrorImage:
      const verticalSymmetric = {
        'A', 'H', 'I', 'M', 'O', 'T', 'U', 'V', 'W', 'X', 'Y',
      };
      const horizontalSymmetric = {'B', 'C', 'D', 'E', 'H', 'I', 'K', 'O', 'X'};
      const mirrorPairs = {'b': 'd', 'd': 'b', 'p': 'q', 'q': 'p'};
      final pairMatch =
          RegExp(r"image of the letter '(\w)'").firstMatch(puzzle.questionText);
      if (pairMatch != null) {
        expect(mirrorPairs[pairMatch.group(1)!], equals(puzzle.correctAnswer));
      } else if (puzzle.questionText.contains('vertical mirror')) {
        expect(verticalSymmetric.contains(puzzle.correctAnswer), isTrue);
      } else {
        expect(horizontalSymmetric.contains(puzzle.correctAnswer), isTrue);
      }

    case PuzzleType.paperFolding:
      final m = RegExp(r'folded in half (\d+) time.+?(\d+) hole')
          .firstMatch(puzzle.questionText)!;
      final folds = int.parse(m.group(1)!);
      final holes = int.parse(m.group(2)!);
      var expected = holes;
      for (var i = 0; i < folds; i++) {
        expected *= 2;
      }
      expect(expected, equals(puzzle.correctAnswer));

    case PuzzleType.figureSeries:
      final m = RegExp(r'^([A-Z]), ([A-Z]), ([A-Z]), ([A-Z]), \?')
          .firstMatch(puzzle.questionText)!;
      final letters = [m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!];
      final codes = letters.map((l) => l.codeUnitAt(0) - 65).toList();
      final step = codes[1] - codes[0];
      expect(codes[2] - codes[1], equals(step));
      expect(codes[3] - codes[2], equals(step));
      final expectedCode = ((codes[3] + step) % 26 + 26) % 26;
      expect(
        (puzzle.correctAnswer as String).codeUnitAt(0) - 65,
        equals(expectedCode),
      );

    case PuzzleType.seatingArrangement:
      final orderMatch =
          RegExp(r'in this order: (.+?)\.').firstMatch(puzzle.questionText)!;
      final names = orderMatch.group(1)!.split(', ');
      final neighbor =
          RegExp(r'immediately to the right of (\w+)').firstMatch(puzzle.questionText);
      final between =
          RegExp(r'between (\w+) and (\w+)').firstMatch(puzzle.questionText);
      final position =
          RegExp(r'Who is (\d+)\w+ from the left').firstMatch(puzzle.questionText);
      if (neighbor != null) {
        final i = names.indexOf(neighbor.group(1)!);
        expect(names[i + 1], equals(puzzle.correctAnswer));
      } else if (between != null) {
        final i = names.indexOf(between.group(1)!);
        final j = names.indexOf(between.group(2)!);
        expect((i - j).abs() - 1, equals(puzzle.correctAnswer));
      } else {
        final fromLeft = int.parse(position!.group(1)!);
        expect(names[fromLeft - 1], equals(puzzle.correctAnswer));
      }

    case PuzzleType.coding:
      final shift = RegExp(r'code, (\w+) is written as (\w+)').firstMatch(puzzle.questionText);
      if (shift != null) {
        final sample = shift.group(1)!;
        final samplecoded = shift.group(2)!;
        final shiftAmount =
            (samplecoded.codeUnitAt(0) - sample.codeUnitAt(0) + 26) % 26;
        final target =
            RegExp(r'will (\w+) be written').firstMatch(puzzle.questionText)!.group(1)!;
        final expected = String.fromCharCodes(
          target.codeUnits.map((c) => ((c - 65 + shiftAmount) % 26) + 65),
        );
        expect(expected, equals(puzzle.correctAnswer));
      } else {
        final word =
            RegExp(r'is the word (\w+) written').firstMatch(puzzle.questionText)!.group(1)!;
        final expected = word.codeUnits.map((c) => c - 64).join('-');
        expect(expected, equals(puzzle.correctAnswer));
      }

    case PuzzleType.directionSense:
      final displacement = RegExp(r'walks (\d+) km towards \w+, then turns '
              r'(right|left) and walks (\d+) km')
          .firstMatch(puzzle.questionText);
      if (displacement != null) {
        final leg1 = int.parse(displacement.group(1)!);
        final leg2 = int.parse(displacement.group(3)!);
        final hyp = sqrt(leg1 * leg1 + leg2 * leg2).round();
        expect(hyp, equals(puzzle.correctAnswer));
      } else {
        const compass = ['North', 'East', 'South', 'West'];
        final startMatch =
            RegExp(r'starts facing (\w+)').firstMatch(puzzle.questionText)!;
        var facing = compass.indexOf(startMatch.group(1)!);
        for (final turnMatch in RegExp(r'turns (180°|right|left)')
            .allMatches(puzzle.questionText)) {
          final t = turnMatch.group(1)!;
          if (t == '180°') {
            facing = (facing + 2) % 4;
          } else if (t == 'right') {
            facing = (facing + 1) % 4;
          } else {
            facing = (facing + 3) % 4;
          }
        }
        expect(compass[facing], equals(puzzle.correctAnswer));
      }

    case PuzzleType.wordPuzzle:
      // The categorization rule itself lives in a curated bank inside the
      // generator (no formula to re-derive independently) — verified here
      // structurally instead: exactly one of the 4 options is the stated
      // correct answer, and it's genuinely present among them.
      expect(puzzle.options, contains(puzzle.correctAnswer));
      expect(puzzle.options.toSet().length, equals(4));

    case PuzzleType.analogy:
      // Same rationale as wordPuzzle above — the A:B::C:D relationship
      // comes from a curated bank, checked structurally here.
      expect(puzzle.options, contains(puzzle.correctAnswer));
      expect(puzzle.options.toSet().length, equals(4));

    case PuzzleType.ranking:
      final conversion =
          RegExp(r'class of (\d+) students, Rahul ranks (\d+)\w+ from the '
                  r'(top|bottom)')
              .firstMatch(puzzle.questionText);
      if (conversion != null) {
        final total = int.parse(conversion.group(1)!);
        final rank = int.parse(conversion.group(2)!);
        final expected = total - rank + 1;
        expect(expected, equals(puzzle.correctAnswer));
      } else {
        // "N1 is taller than N2. N2 is taller than N3. ... " — a strictly
        // linear chain by construction, so the first match's subject is
        // the overall tallest and the last match's object is the overall
        // shortest, transitively.
        final comparisons =
            RegExp(r'(\w+) is taller than (\w+)').allMatches(puzzle.questionText).toList();
        final tallest = comparisons.first.group(1)!;
        final shortest = comparisons.last.group(2)!;
        expect(
          puzzle.questionText.contains('tallest') ? tallest : shortest,
          equals(puzzle.correctAnswer),
        );
      }

    case PuzzleType.statementConclusion:
      // "All A are B. All B are C." -> "All A are C." is valid;
      // "All A are C. All B are C." -> "All A are B." is not (sharing C
      // doesn't link A and B) — independently re-derived from which
      // pattern the statements/conclusion actually take, not by trusting
      // the generator's own isValid flag.
      final m = RegExp(
              r'All (.+?) are (.+?)\. All (.+?) are (.+?)\.\nConclusion: '
              r'All (.+?) are (.+?)\.')
          .firstMatch(puzzle.questionText)!;
      final validChain = m.group(2) == m.group(3) &&
          m.group(1) == m.group(5) &&
          m.group(4) == m.group(6);
      expect(validChain, equals(puzzle.correctAnswer));
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

// Re-typed independently here (not imported from rng_utils.dart) for the
// same reason _independentSideCounts/_relationshipVocabulary are - a bug
// in the generator's own gcd should actually be caught, not agreed with.
int _gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = y;
    y = x % y;
    x = t;
  }
  return x == 0 ? 1 : x;
}

int _factorial(int n) {
  var result = 1;
  for (var i = 2; i <= n; i++) {
    result *= i;
  }
  return result;
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
          if (type == PuzzleType.trueFalse ||
              type == PuzzleType.statementConclusion) {
            expect(puzzle.options, equals(['True', 'False']));
          } else if (type == PuzzleType.numberClassification &&
              puzzle.correctAnswer is bool) {
            // The prime-check sub-case is True/False like trueFalse above;
            // the classify sub-case (correctAnswer is a String) still uses
            // the standard 4-option MC format below.
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

          // Hint rule (all-modes, Phase 11): every formula-driven type
          // populates a hint at every tier now — except graphReading,
          // which never has one (reading a graph isn't formula-driven)
          // and the pre-existing types, which never populate hint at all.
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
            PuzzleType.numberClassification,
            PuzzleType.surds,
            PuzzleType.algebraicIdentity,
            PuzzleType.linearEquation,
            PuzzleType.quadraticEquation,
            PuzzleType.progression,
            PuzzleType.trigRatio,
            PuzzleType.mensurationAdvanced,
            PuzzleType.coordinateGeometry,
            PuzzleType.logarithm,
            PuzzleType.permutationCombination,
            PuzzleType.statistics,
            PuzzleType.unitConversion,
            PuzzleType.workTime,
            PuzzleType.mixtureAlligation,
            PuzzleType.mirrorImage,
            PuzzleType.paperFolding,
            PuzzleType.figureSeries,
            PuzzleType.seatingArrangement,
            PuzzleType.coding,
            PuzzleType.directionSense,
            PuzzleType.wordPuzzle,
            PuzzleType.analogy,
            PuzzleType.ranking,
            PuzzleType.statementConclusion,
          };
          if (hintedTypes.contains(type)) {
            expect(puzzle.hint, isNotNull);
            expect(puzzle.hint, isNotEmpty);
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
    // shapeIdentification, coordinateDistance, graphReading, probability,
    // and numberClassification are deliberately excluded here.
    // shapeIdentification/coordinateDistance: small possibility spaces (16
    // texts; a handful of Pythagorean triples × 2 for the x/y swap) that
    // make a literal "10 draws, zero duplicates" check flaky by the
    // birthday paradox. graphReading: its "which category has the
    // highest/second-highest value?" question variant deliberately
    // doesn't name a category in the text (the answer itself is the
    // category), so only 2 distinct texts exist for that variant
    // regardless of which values were actually generated — real variety
    // lives in diagramData/correctAnswer instead, checked in
    // graph_reading_generator_test.dart. probability: the die sub-case
    // alone has only 5 possible question texts (thresholds 1-5), and it's
    // a 1-in-3 pick each draw — the same birthday-paradox flake risk,
    // checked instead in probability_generator_test.dart.
    // numberClassification: two sub-cases each drawing from a bounded n
    // range (prime-check picks a single n directly, no independent
    // "variety" source beyond it), the same class of flake risk.
    // trigRatio: its standard-angle-lookup sub-case draws from a small
    // fixed table (5 angles × up to 3 ratios), the same risk again.
    // workTime: both sub-cases draw from small curated (individual-time,
    // combined-time) pair pools (as few as 4 pairs at tier 1) rather than
    // a wide random range, needed to keep every combined answer an exact
    // integer. mirrorImage: two of its three sub-cases each have only one
    // fixed question stem ("Which letter looks exactly the same in a
    // mirror..."), varying only in which single letter is correct — real
    // variety lives in correctAnswer, not questionText. paperFolding: at
    // tier 3 (folds 1-3 × holes 1-2, 6 combos) the same small-space flake
    // risk. wordPuzzle: its questionText is a fixed constant ("Which word
    // does NOT belong with the others?") — real variety lives entirely in
    // options/correctAnswer, same as mirrorImage's lookup sub-cases.
    // analogy: its curated bank (14 entries at tier 3-4) is still small
    // enough for the same birthday-paradox flake risk. statementConclusion:
    // only 6 curated triples × 2 (valid/invalid) = 12 possible texts, the
    // same risk again. See shape_reasoning_generator_test.dart for the
    // same dedicated-variety-check pattern.
    for (final type in PuzzleType.values.where(
      (t) =>
          t != PuzzleType.shapeIdentification &&
          t != PuzzleType.coordinateDistance &&
          t != PuzzleType.graphReading &&
          t != PuzzleType.probability &&
          t != PuzzleType.numberClassification &&
          t != PuzzleType.trigRatio &&
          t != PuzzleType.workTime &&
          t != PuzzleType.mirrorImage &&
          t != PuzzleType.paperFolding &&
          t != PuzzleType.wordPuzzle &&
          t != PuzzleType.analogy &&
          t != PuzzleType.statementConclusion,
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
