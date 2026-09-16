import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Analogy (Phase 12, reasoning topic 8): "A is to B as C is to ?" — a
/// curated bank of (A, B, C, D) quadruples grouped by relationship type,
/// so every distractor pool can be drawn from *other* quadruples' D
/// values without accidentally matching the correct answer semantically.
abstract final class AnalogyGenerator {
  // (A, B, C, D) — A:B :: C:D. Grouped loosely from simpler (tier 1-2)
  // to more abstract (tier 3-4) relationships.
  static const _easyBank = [
    ('Dog', 'Puppy', 'Cat', 'Kitten'),
    ('Cow', 'Calf', 'Horse', 'Foal'),
    ('Doctor', 'Hospital', 'Teacher', 'School'),
    ('Pen', 'Write', 'Knife', 'Cut'),
    ('Bird', 'Sky', 'Fish', 'Water'),
    ('Hot', 'Cold', 'Day', 'Night'),
    ('Foot', 'Shoe', 'Hand', 'Glove'),
    ('Author', 'Book', 'Painter', 'Painting'),
  ];
  static const _hardBank = [
    ('Thermometer', 'Temperature', 'Clock', 'Time'),
    ('Tailor', 'Cloth', 'Carpenter', 'Wood'),
    ('Herbivore', 'Plants', 'Carnivore', 'Meat'),
    ('Library', 'Books', 'Museum', 'Artifacts'),
    ('Oxygen', 'Breathing', 'Food', 'Digestion'),
    ('Judge', 'Court', 'Referee', 'Field'),
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final bank = tier >= 3 ? [..._easyBank, ..._hardBank] : _easyBank;
    final entry = bank[rng.nextInt(0, bank.length - 1)];
    final (a, b, c, d) = entry;

    final otherDs = bank
        .where((e) => e != entry)
        .map((e) => e.$4)
        .toSet()
        .toList();
    shuffleList(otherDs, rng);

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.analogy,
      questionText: '$a is to $b as $c is to ?',
      options: buildMcOptionsFromCandidates(d, otherDs, rng),
      correctAnswer: d,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: 'Work out the relationship between the first pair, then apply it.',
    );
  }
}
