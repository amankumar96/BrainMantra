import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/services/difficulty_curve.dart';
import 'package:brain_mantra/services/rng_service.dart';
import 'package:brain_mantra/services/shape_reasoning_generator.dart';

// A small side-count table re-typed independently here (not imported from
// the generator) so a bug in the generator's own table would actually be
// caught by these tests, rather than the test trivially agreeing with
// whatever the generator already believes.
const _independentSideCounts = {
  'triangle': 3,
  'square': 4,
  'pentagon': 5,
  'hexagon': 6,
  'heptagon': 7,
  'octagon': 8,
  'nonagon': 9,
  'decagon': 10,
};

void main() {
  group('generated puzzle shape, across all tiers', () {
    for (final tier in [1, 2, 3, 4]) {
      test('tier $tier: 200 generations are well-formed and correct', () {
        for (var i = 0; i < 200; i++) {
          final puzzle = ShapeReasoningGenerator.generate(
            tier: tier,
            rng: RngService.free(),
          );

          expect(puzzle.category, equals(PuzzleCategory.reasoningTest));
          expect(puzzle.type, equals(PuzzleType.shapeIdentification));
          expect(puzzle.difficultyTier, equals(tier));
          expect(
            puzzle.timeLimitSeconds,
            equals(DifficultyCurve.paramsForTier(tier).timeLimitSeconds),
          );

          // 4 unique options, correct answer among them.
          expect(puzzle.options, hasLength(4));
          expect(puzzle.options.toSet().length, equals(4));
          expect(
            puzzle.options,
            contains(puzzle.correctAnswer.toString()),
          );

          // Independently re-derive the correct answer from the
          // side-count table above (not from the generator's internals).
          if (puzzle.correctAnswer is int) {
            // "How many sides does a {shape} have?" phrasing.
            final shapeName = RegExp(r'a (\w+) have')
                .firstMatch(puzzle.questionText)!
                .group(1)!;
            expect(
              puzzle.correctAnswer,
              equals(_independentSideCounts[shapeName]),
            );
          } else {
            // "Which shape has {n} sides?" phrasing.
            expect(puzzle.correctAnswer, isA<String>());
            final sideCount = int.parse(
              RegExp(r'has (\d+) sides')
                  .firstMatch(puzzle.questionText)!
                  .group(1)!,
            );
            expect(
              _independentSideCounts[puzzle.correctAnswer as String],
              equals(sideCount),
            );
          }
        }
      });
    }
  });

  group('determinism', () {
    test('same seeded RngService produces an identical puzzle twice', () {
      final a = ShapeReasoningGenerator.generate(
        tier: 2,
        rng: RngService.seeded('shape-seed'),
      );
      final b = ShapeReasoningGenerator.generate(
        tier: 2,
        rng: RngService.seeded('shape-seed'),
      );
      expect(a, equals(b));
    });
  });

  group('variety', () {
    // Only 8 shapes x 2 phrasings = 16 possible distinct question texts
    // total, so a literal "N draws, zero duplicates" check (as used for
    // other puzzle types, which have effectively unbounded entropy from
    // random operand pairs / names) is the WRONG test here — with only 16
    // possible outcomes, the birthday paradox makes even a handful of
    // draws collide close to half the time purely by chance (verified:
    // 6 draws collided on the very first seed tried during development).
    // Instead, check for real variety over a larger sample: the generator
    // shouldn't be effectively stuck returning the same one or two texts.
    test('100 generations from one seed produce meaningfully varied '
        'questionText values (not a static/near-static generator)', () {
      final rng = RngService.seeded('shape-variety');
      final texts = List.generate(
        100,
        (_) => ShapeReasoningGenerator.generate(tier: 2, rng: rng)
            .questionText,
      );
      // Out of 16 possible texts, seeing at least 8 distinct ones across
      // 100 draws is a conservative bar — comfortably cleared by a
      // healthy RNG, but would fail fast if the generator were broken
      // (e.g. always picking the same shape/phrasing).
      expect(texts.toSet().length, greaterThanOrEqualTo(8));
    });
  });
}
