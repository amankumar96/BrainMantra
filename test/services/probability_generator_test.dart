import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/probability_generator.dart';
import 'package:math_blitz/services/rng_service.dart';

void main() {
  group('variety', () {
    // Excluded from puzzle_generator_test.dart's shared anti-duplicate
    // check — the die sub-case alone has only 5 possible question texts
    // (thresholds 1-5), which makes a literal "10 draws, zero duplicates"
    // check flaky by the birthday paradox. This checks real variety over
    // a larger sample instead. See coordinate_distance_generator_test.dart
    // for the same pattern.
    test('produces more than one distinct question over 30 draws', () {
      final rng = RngService.seeded('probability-variety');
      final texts = {
        for (var i = 0; i < 30; i++)
          ProbabilityGenerator.generate(tier: 3, rng: rng).questionText,
      };
      expect(texts.length, greaterThan(1));
    });

    test('produces more than one distinct correct fraction over 30 draws',
        () {
      final rng = RngService.seeded('probability-answer-variety');
      final answers = {
        for (var i = 0; i < 30; i++)
          ProbabilityGenerator.generate(tier: 3, rng: rng).correctAnswer,
      };
      expect(answers.length, greaterThan(1));
    });
  });

  group('fraction correctness', () {
    test('correctAnswer is always an already-reduced fraction string', () {
      final rng = RngService.seeded('probability-reduced');
      for (var i = 0; i < 200; i++) {
        final puzzle = ProbabilityGenerator.generate(tier: 3, rng: rng);
        final parts = (puzzle.correctAnswer as String).split('/');
        expect(parts, hasLength(2));
        final f = int.parse(parts[0]);
        final t = int.parse(parts[1]);
        int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
        expect(gcd(f, t), equals(1),
            reason: 'unreduced: ${puzzle.correctAnswer}');
        expect(t, greaterThan(0));
        expect(f, greaterThanOrEqualTo(0));
      }
    });
  });
}
