import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Unit Conversions (Phase 11B, topics 15 & 21): length/weight/time
/// conversions and percentage↔ratio, each direction picked at random.
abstract final class UnitConversionGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return switch (rng.nextInt(0, 3)) {
      0 => _length(tier, params.timeLimitSeconds, rng),
      1 => _weight(tier, params.timeLimitSeconds, rng),
      2 => _time(tier, params.timeLimitSeconds, rng),
      _ => _percentToRatio(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _length(int tier, int timeLimitSeconds, RngService rng) {
    final n = rng.nextInt(2, _rangeForTier(tier));
    final toSmaller = rng.nextBool();
    final answer = n * 1000;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: toSmaller
          ? 'Convert $n km to metres.'
          : 'Convert ${n * 1000} m to kilometres.',
      options: buildNumericMcOptions(
        toSmaller ? answer : n,
        rng,
        spread: toSmaller ? answer ~/ 10 : 2,
      ),
      correctAnswer: toSmaller ? answer : n,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: '1 km = 1000 m',
    );
  }

  static Puzzle _weight(int tier, int timeLimitSeconds, RngService rng) {
    final n = rng.nextInt(2, _rangeForTier(tier));
    final toSmaller = rng.nextBool();
    final answer = n * 1000;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: toSmaller
          ? 'Convert $n kg to grams.'
          : 'Convert ${n * 1000} g to kilograms.',
      options: buildNumericMcOptions(
        toSmaller ? answer : n,
        rng,
        spread: toSmaller ? answer ~/ 10 : 2,
      ),
      correctAnswer: toSmaller ? answer : n,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: '1 kg = 1000 g',
    );
  }

  static Puzzle _time(int tier, int timeLimitSeconds, RngService rng) {
    final n = rng.nextInt(1, _rangeForTier(tier).clamp(2, 12));
    final toSmaller = rng.nextBool();
    final answer = n * 60;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: toSmaller
          ? 'Convert $n hours to minutes.'
          : 'Convert ${n * 60} minutes to hours.',
      options: buildNumericMcOptions(
        toSmaller ? answer : n,
        rng,
        spread: toSmaller ? 30 : 2,
      ),
      correctAnswer: toSmaller ? answer : n,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: '1 hour = 60 minutes',
    );
  }

  static Puzzle _percentToRatio(
    int tier,
    int timeLimitSeconds,
    RngService rng,
  ) {
    const cleanPercents = [10, 20, 25, 40, 50, 60, 75, 80];
    final p = cleanPercents[rng.nextInt(0, cleanPercents.length - 1)];
    final g = gcd(p, 100);
    final correct = '${p ~/ g}:${100 ~/ g}';
    final candidates = {
      correct,
      '$p:100',
      '${p ~/ g}:${(100 ~/ g) + 1}',
      '${(p ~/ g) + 1}:${100 ~/ g}',
      '${100 ~/ g}:${p ~/ g}',
    }..remove(correct);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: 'Express $p% as a ratio in simplest form.',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'p% = p/100, then reduce to lowest terms.',
    );
  }

  static int _rangeForTier(int tier) => switch (tier) {
        1 => 6,
        2 => 10,
        3 => 15,
        _ => 20,
      };
}
