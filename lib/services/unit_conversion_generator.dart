import '../models/app_language.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Unit Conversions (Phase 11B, topics 15 & 21): length/weight/time
/// conversions and percentage↔ratio, each direction picked at random.
abstract final class UnitConversionGenerator {
  static Puzzle generate({
    required int tier,
    required RngService rng,
    required AppLanguage language,
  }) {
    final params = DifficultyCurve.paramsForTier(tier);
    return switch (rng.nextInt(0, 3)) {
      0 => _length(tier, params.timeLimitSeconds, rng, language),
      1 => _weight(tier, params.timeLimitSeconds, rng, language),
      2 => _time(tier, params.timeLimitSeconds, rng, language),
      _ => _percentToRatio(tier, params.timeLimitSeconds, rng, language),
    };
  }

  static Puzzle _length(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final n = rng.nextInt(2, _rangeForTier(tier));
    final toSmaller = rng.nextBool();
    final answer = n * 1000;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: language == AppLanguage.english
          ? (toSmaller
              ? 'Convert $n km to metres.'
              : 'Convert ${n * 1000} m to kilometres.')
          : (toSmaller
              ? '$n km को metres में बदलें।'
              : '${n * 1000} m को kilometres में बदलें।'),
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

  static Puzzle _weight(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final n = rng.nextInt(2, _rangeForTier(tier));
    final toSmaller = rng.nextBool();
    final answer = n * 1000;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: language == AppLanguage.english
          ? (toSmaller
              ? 'Convert $n kg to grams.'
              : 'Convert ${n * 1000} g to kilograms.')
          : (toSmaller
              ? '$n kg को grams में बदलें।'
              : '${n * 1000} g को kilograms में बदलें।'),
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

  static Puzzle _time(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final n = rng.nextInt(1, _rangeForTier(tier).clamp(2, 12));
    final toSmaller = rng.nextBool();
    final answer = n * 60;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.unitConversion,
      questionText: language == AppLanguage.english
          ? (toSmaller
              ? 'Convert $n hours to minutes.'
              : 'Convert ${n * 60} minutes to hours.')
          : (toSmaller
              ? '$n घंटे को मिनटों में बदलें।'
              : '${n * 60} मिनट को घंटों में बदलें।'),
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
    AppLanguage language,
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
      questionText: language == AppLanguage.english
          ? 'Express $p% as a ratio in simplest form.'
          : '$p% को सरलतम रूप में अनुपात के रूप में व्यक्त करें।',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: language == AppLanguage.english
          ? 'p% = p/100, then reduce to lowest terms.'
          : 'p% = p/100, फिर सरलतम रूप में बदलें।',
    );
  }

  static int _rangeForTier(int tier) => switch (tier) {
        1 => 6,
        2 => 10,
        3 => 15,
        _ => 20,
      };
}
