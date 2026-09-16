import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Ranking (Phase 12, reasoning topic 9): rank-from-the-other-end
/// conversion (rank from bottom = total − rank from top + 1), and a
/// simple "who's between" comparative-ranking puzzle.
abstract final class RankingGenerator {
  static const _names = ['Aarav', 'Priya', 'Rohan', 'Isha', 'Kabir'];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _rankConversion(tier, params.timeLimitSeconds, rng)
        : _comparative(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _rankConversion(
    int tier,
    int timeLimitSeconds,
    RngService rng,
  ) {
    final range = switch (tier) {
      1 => (min: 10, max: 20),
      2 => (min: 15, max: 30),
      3 => (min: 20, max: 50),
      _ => (min: 30, max: 80),
    };
    final total = rng.nextInt(range.min, range.max);
    final rankFromTop = rng.nextInt(1, total);
    final rankFromBottom = total - rankFromTop + 1;
    final askFromBottom = rng.nextBool();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.ranking,
      questionText: askFromBottom
          ? 'In a class of $total students, Rahul ranks $rankFromTop'
              '${_suffix(rankFromTop)} from the top. What is his rank '
              'from the bottom?'
          : 'In a class of $total students, Rahul ranks $rankFromBottom'
              '${_suffix(rankFromBottom)} from the bottom. What is his '
              'rank from the top?',
      options: buildNumericMcOptions(
        askFromBottom ? rankFromBottom : rankFromTop,
        rng,
        spread: 4,
      ),
      correctAnswer: askFromBottom ? rankFromBottom : rankFromTop,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Rank from bottom = Total − Rank from top + 1',
    );
  }

  static Puzzle _comparative(int tier, int timeLimitSeconds, RngService rng) {
    final names = List.of(_names);
    shuffleList(names, rng);
    // names[0] scores highest, names[last] scores lowest.
    final tallest = names.first;
    final shortest = names.last;
    final askTallest = rng.nextBool();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.ranking,
      questionText: '${names[0]} is taller than ${names[1]}. ${names[1]} '
          'is taller than ${names[2]}. ${names[2]} is taller than '
          '${names[3]}. ${names[3]} is taller than ${names[4]}. Who is '
          'the ${askTallest ? 'tallest' : 'shortest'}?',
      options: buildMcOptionsFromCandidates(
        askTallest ? tallest : shortest,
        names.where((n) => n != (askTallest ? tallest : shortest)).toList(),
        rng,
      ),
      correctAnswer: askTallest ? tallest : shortest,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Chain the comparisons in order from first to last.',
    );
  }

  static String _suffix(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return 'th';
    return switch (n % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }
}
