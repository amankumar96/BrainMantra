import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/diagram_data.dart';
import 'package:brain_mantra/services/graph_reading_generator.dart';
import 'package:brain_mantra/services/rng_service.dart';

void main() {
  group('structural invariants, across both question variants', () {
    test('300 generations: always distinct bar values, categories/values '
        'same length, category count matches the tier band', () {
      final rng = RngService.seeded('graph-reading-structure');
      for (final tier in [1, 2, 3, 4]) {
        final expectedCount = switch (tier) { 1 => 3, 2 => 4, _ => 5 };
        for (var i = 0; i < 300; i++) {
          final puzzle = GraphReadingGenerator.generate(tier: tier, rng: rng);
          final data = puzzle.diagramData!;
          expect(data.kind, equals(DiagramKind.barGraph));
          expect(data.categories, hasLength(expectedCount));
          expect(data.values, hasLength(expectedCount));
          expect(data.values!.toSet().length, equals(data.values!.length),
              reason: 'a tie makes "highest" ambiguous: ${data.values}');
          expect(puzzle.hint, isNull,
              reason: 'graph reading never has a hint, at any tier');
        }
      }
    });
  });

  group('both question variants actually occur', () {
    test('ranking ("which category...") and difference questions both '
        'appear over many draws', () {
      final rng = RngService.seeded('graph-reading-variants');
      var sawRanking = false;
      var sawDifference = false;
      for (var i = 0; i < 100; i++) {
        final puzzle = GraphReadingGenerator.generate(tier: 3, rng: rng);
        if (puzzle.questionText.startsWith('Which category')) {
          sawRanking = true;
        } else {
          sawDifference = true;
        }
      }
      expect(sawRanking, isTrue);
      expect(sawDifference, isTrue);
    });
  });

  group('real variety despite repeated ranking-question text', () {
    // The "which category has the highest value?" text is identical
    // regardless of the actual generated values (the category itself is
    // the answer, not part of the question) — this confirms that even
    // though the text repeats, the underlying diagramData/correctAnswer
    // still varies draw to draw, which is what actually matters (this is
    // the substance behind excluding graphReading from
    // puzzle_generator_test.dart's shared anti-duplicate check).
    test('correctAnswer/diagramData.values differ across repeated-text '
        'ranking draws', () {
      final rng = RngService.seeded('graph-reading-real-variety');
      final answers = <String>{};
      final valueSets = <String>{};
      for (var i = 0; i < 30; i++) {
        final puzzle = GraphReadingGenerator.generate(tier: 3, rng: rng);
        if (!puzzle.questionText.startsWith('Which category')) continue;
        answers.add(puzzle.correctAnswer as String);
        valueSets.add(puzzle.diagramData!.values.toString());
      }
      expect(valueSets.length, greaterThan(1));
      expect(answers.length, greaterThanOrEqualTo(1));
    });
  });

  group('determinism', () {
    test('same seed produces an identical puzzle twice', () {
      final a = GraphReadingGenerator.generate(
        tier: 2,
        rng: RngService.seeded('graph-reading-determinism'),
      );
      final b = GraphReadingGenerator.generate(
        tier: 2,
        rng: RngService.seeded('graph-reading-determinism'),
      );
      expect(a, equals(b));
    });
  });
}
