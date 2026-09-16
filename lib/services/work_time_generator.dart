import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Work, Time, Pipe & Cistern (Phase 11B, topic 16): "A and B together"
/// combined-work problems, and a pipe-fills/pipe-empties net-time problem
/// — both drawn from curated (individual-time, combined-time) pairs so
/// every combined answer is an exact integer (xy/(x±y) rarely divides
/// evenly for arbitrary x,y, so this avoids a messy validity-search loop).
abstract final class WorkTimeGenerator {
  // (A's days, B's days, combined days) — xy/(x+y) exact for each.
  static const _combinedWorkPairs = [
    (2, 2, 1), (4, 4, 2), (6, 6, 3), (6, 3, 2), (9, 18, 6),
    (4, 12, 3), (10, 15, 6), (8, 8, 4), (12, 12, 6), (20, 5, 4),
    (15, 10, 6), (18, 9, 6), (24, 8, 6), (30, 20, 12),
  ];

  // (fill hours, empty hours, net-fill hours) — xy/(y-x) exact, y>x.
  static const _pipeCisternPairs = [
    (2, 4, 4), (3, 6, 6), (4, 8, 8), (2, 6, 3), (6, 9, 18),
    (4, 12, 6), (6, 12, 12), (5, 10, 10), (2, 3, 6), (4, 20, 5),
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _combinedWork(tier, params.timeLimitSeconds, rng)
        : _pipeCistern(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _combinedWork(int tier, int timeLimitSeconds, RngService rng) {
    final pool = _poolForTier(tier, _combinedWorkPairs);
    final (a, b, combined) = pool[rng.nextInt(0, pool.length - 1)];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.workTime,
      questionText: 'A can finish a job in $a days, B can finish the same '
          'job in $b days. Working together, how many days will they '
          'take?',
      options: buildNumericMcOptions(combined, rng, spread: 3),
      correctAnswer: combined,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Combined rate = 1/A_days + 1/B_days; time = 1/(combined rate)',
    );
  }

  static Puzzle _pipeCistern(int tier, int timeLimitSeconds, RngService rng) {
    final pool = _poolForTier(tier, _pipeCisternPairs);
    final (fill, empty, net) = pool[rng.nextInt(0, pool.length - 1)];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.workTime,
      questionText: 'Pipe A fills a tank in $fill hours. Pipe B empties '
          'the same tank in $empty hours. If both are open together, how '
          'many hours to fill the tank?',
      options: buildNumericMcOptions(net, rng, spread: 3),
      correctAnswer: net,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: '1/t = 1/A_hours - 1/B_hours (net fill rate)',
    );
  }

  /// TUNABLE — smaller/simpler pairs at low tiers, the full pool at
  /// tier 4. Takes at least 4 entries always, so the pick is never
  /// degenerate even at tier 1.
  static List<(int, int, int)> _poolForTier(
    int tier,
    List<(int, int, int)> all,
  ) {
    final count = switch (tier) {
      1 => 4,
      2 => 7,
      3 => 10,
      _ => all.length,
    };
    return all.take(count).toList();
  }
}
