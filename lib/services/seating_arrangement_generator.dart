import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Seating Arrangements (Phase 12, reasoning topic 4): a row of names in
/// a stated order, asked about relative position — "who's immediately
/// left/right of X", "how many sit between X and Y", "who's in the
/// middle". The order is stated directly (not left for the player to
/// deduce from partial clues) since guaranteeing a *uniquely solvable*
/// clue set needs a real constraint solver this project doesn't have —
/// this still genuinely exercises reading a stated arrangement and
/// reasoning about relative position, the actual skill this topic tests.
abstract final class SeatingArrangementGenerator {
  static const _namePool = [
    'Aarav', 'Priya', 'Rohan', 'Isha', 'Kabir',
    'Meera', 'Vikram', 'Sara',
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final count = switch (tier) {
      1 => 4,
      2 => 5,
      3 => 6,
      _ => 7,
    };
    final names = List.of(_namePool.take(count));
    shuffleList(names, rng);

    return switch (rng.nextInt(0, 2)) {
      0 => _neighbor(tier, params.timeLimitSeconds, rng, names),
      1 => _between(tier, params.timeLimitSeconds, rng, names),
      _ => _position(tier, params.timeLimitSeconds, rng, names),
    };
  }

  static Puzzle _neighbor(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    List<String> names,
  ) {
    // Pick an index that has a right neighbor.
    final i = rng.nextInt(0, names.length - 2);
    final correct = names[i + 1];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.seatingArrangement,
      questionText: '${names.length} friends sit in a row, left to '
          'right, in this order: ${names.join(', ')}. Who sits '
          'immediately to the right of ${names[i]}?',
      options: buildMcOptionsFromCandidates(
        correct,
        names.where((n) => n != correct).toList(),
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Read the stated left-to-right order directly.',
    );
  }

  static Puzzle _between(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    List<String> names,
  ) {
    final i = rng.nextInt(0, names.length - 1);
    var j = rng.nextInt(0, names.length - 1);
    while (j == i) {
      j = rng.nextInt(0, names.length - 1);
    }
    final between = (i - j).abs() - 1;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.seatingArrangement,
      questionText: '${names.length} friends sit in a row, left to '
          'right, in this order: ${names.join(', ')}. How many people '
          'sit between ${names[i]} and ${names[j]}?',
      options: buildNumericMcOptions(between, rng, spread: 2),
      correctAnswer: between,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Count the positions strictly between the two named people.',
    );
  }

  static Puzzle _position(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    List<String> names,
  ) {
    final fromLeft = rng.nextInt(1, names.length);
    final correct = names[fromLeft - 1];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.seatingArrangement,
      questionText: '${names.length} friends sit in a row, left to '
          'right, in this order: ${names.join(', ')}. Who is $fromLeft'
          '${_ordinalSuffix(fromLeft)} from the left?',
      options: buildMcOptionsFromCandidates(
        correct,
        names.where((n) => n != correct).toList(),
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Count positions from the left end of the stated order.',
    );
  }

  static String _ordinalSuffix(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return 'th';
    return switch (n % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }
}
