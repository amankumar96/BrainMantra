import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Statistics (Phase 11B, topic 14): mean, median, mode, range on a small
/// dataset built so every answer is an exact integer, plus — tier 3-4 —
/// variance on a symmetric dataset (mean-2d, mean-d, mean, mean+d,
/// mean+2d), whose variance is always exactly 2d².
abstract final class StatisticsGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    if (tier >= 3 && rng.nextBool()) {
      return _variance(tier, params.timeLimitSeconds, rng);
    }
    return switch (rng.nextInt(0, 3)) {
      0 => _mean(tier, params.timeLimitSeconds, rng),
      1 => _median(tier, params.timeLimitSeconds, rng),
      2 => _mode(tier, params.timeLimitSeconds, rng),
      _ => _range(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _mean(int tier, int timeLimitSeconds, RngService rng) {
    final range = _valueRangeForTier(tier);
    final count = rng.nextInt(4, 6);
    // Sum built as count × mean + a zero-sum remainder, so the mean is
    // always an exact integer without needing to check divisibility.
    final mean = rng.nextInt(range.min, range.max);
    final values = List.generate(count, (_) => mean);
    for (var i = 0; i + 1 < count; i += 2) {
      final delta = rng.nextInt(1, range.max ~/ 2);
      values[i] += delta;
      values[i + 1] -= delta;
    }
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.statistics,
      questionText: 'Find the mean of: ${values.join(', ')}',
      options: buildNumericMcOptions(mean, rng, spread: _spreadFor(mean)),
      correctAnswer: mean,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Mean = (sum of values) / (count of values)',
    );
  }

  static Puzzle _median(int tier, int timeLimitSeconds, RngService rng) {
    final range = _valueRangeForTier(tier);
    // Odd count -> the median is a single middle element, no averaging
    // needed to keep the answer an exact integer.
    final values = List.generate(
      5,
      (_) => rng.nextInt(range.min, range.max),
    )..sort();
    final median = values[2];
    final shuffled = List.of(values);
    shuffleList(shuffled, rng);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.statistics,
      questionText: 'Find the median of: ${shuffled.join(', ')}',
      options: buildNumericMcOptions(median, rng, spread: _spreadFor(median)),
      correctAnswer: median,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Median: sort the values, take the middle one (odd count).',
    );
  }

  static Puzzle _mode(int tier, int timeLimitSeconds, RngService rng) {
    final range = _valueRangeForTier(tier);
    final mode = rng.nextInt(range.min, range.max);
    // Every "other" value must be distinct from mode *and* from each
    // other — two others colliding would tie the mode's frequency and
    // make the answer genuinely ambiguous.
    final others = <int>{};
    while (others.length < 3) {
      final v = rng.nextInt(range.min, range.max);
      if (v != mode) others.add(v);
    }
    final values = [mode, mode, ...others];
    shuffleList(values, rng);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.statistics,
      questionText: 'Find the mode of: ${values.join(', ')}',
      options: buildNumericMcOptions(mode, rng, spread: _spreadFor(mode)),
      correctAnswer: mode,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Mode = the most frequently occurring value.',
    );
  }

  static Puzzle _range(int tier, int timeLimitSeconds, RngService rng) {
    final valueRange = _valueRangeForTier(tier);
    final values =
        List.generate(5, (_) => rng.nextInt(valueRange.min, valueRange.max));
    final answer =
        values.reduce((a, b) => a > b ? a : b) - values.reduce((a, b) => a < b ? a : b);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.statistics,
      questionText: 'Find the range of: ${values.join(', ')}',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Range = largest value - smallest value',
    );
  }

  static Puzzle _variance(int tier, int timeLimitSeconds, RngService rng) {
    final mean = rng.nextInt(10, 40);
    final d = rng.nextInt(1, 6);
    final values = [mean - 2 * d, mean - d, mean, mean + d, mean + 2 * d];
    final shuffled = List.of(values);
    shuffleList(shuffled, rng);
    final variance = 2 * d * d;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.statistics,
      questionText: 'Find the variance of: ${shuffled.join(', ')}',
      options: buildNumericMcOptions(variance, rng, spread: _spreadFor(variance)),
      correctAnswer: variance,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Variance σ² = Σ(x - mean)² / n',
    );
  }

  static int _spreadFor(int answer) => (answer.abs() * 0.3).round().clamp(2, 100);

  static ({int min, int max}) _valueRangeForTier(int tier) => switch (tier) {
        1 => (min: 1, max: 20),
        2 => (min: 1, max: 40),
        3 => (min: 1, max: 60),
        _ => (min: 1, max: 100),
      };
}
