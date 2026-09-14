import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/coordinate_distance_generator.dart';
import 'package:brain_mantra/services/rng_service.dart';

void main() {
  group('variety', () {
    // Excluded from puzzle_generator_test.dart's shared anti-duplicate
    // check for the same reason shape_reasoning_generator.dart is: a
    // small possibility space (a handful of Pythagorean triples × 2 for
    // the x/y swap) makes "10 draws, zero duplicates" flaky by the
    // birthday paradox, not a sign this generator is actually broken —
    // this checks real variety over a larger sample instead.
    test('produces more than one distinct question over 30 draws', () {
      final rng = RngService.seeded('coordinate-distance-variety');
      final texts = {
        for (var i = 0; i < 30; i++)
          CoordinateDistanceGenerator.generate(tier: 3, rng: rng).questionText,
      };
      expect(texts.length, greaterThan(1));
    });
  });

  group('tier bands', () {
    test('tier 1-2 only ever uses the small starter triples', () {
      final rng = RngService.seeded('coordinate-distance-low-tier');
      const allowedAnswers = {5, 10, 13};
      for (var i = 0; i < 100; i++) {
        final puzzle = CoordinateDistanceGenerator.generate(tier: 1, rng: rng);
        expect(allowedAnswers, contains(puzzle.correctAnswer));
      }
    });

    test('tier 3-4 draws from the larger triple table', () {
      final rng = RngService.seeded('coordinate-distance-high-tier');
      const allowedAnswers = {17, 25, 15, 29, 20};
      for (var i = 0; i < 100; i++) {
        final puzzle = CoordinateDistanceGenerator.generate(tier: 4, rng: rng);
        expect(allowedAnswers, contains(puzzle.correctAnswer));
      }
    });
  });
}
