import '../models/app_language.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Number System (Phase 11B, topic 1): prime checks and classifying an
/// integer into the smallest number set it belongs to.
abstract final class NumberClassificationGenerator {
  static Puzzle generate({
    required int tier,
    required RngService rng,
    required AppLanguage language,
  }) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _primeCheck(tier, params.timeLimitSeconds, rng, language)
        : _classify(tier, params.timeLimitSeconds, rng, language);
  }

  static Puzzle _primeCheck(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final range = _rangeForTier(tier);
    final n = rng.nextInt(range.min, range.max);
    final isPrime = _isPrime(n);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.numberClassification,
      questionText: language == AppLanguage.english
          ? 'Is $n a prime number?'
          : 'क्या $n एक अभाज्य संख्या है?',
      options: const ['True', 'False'],
      correctAnswer: isPrime,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: language == AppLanguage.english
          ? 'A prime number has exactly two factors: 1 and itself.'
          : 'एक अभाज्य संख्या के ठीक दो गुणनखंड होते हैं: 1 और वह संख्या खुद।',
    );
  }

  static Puzzle _classify(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final range = _rangeForTier(tier);
    // Sign picked first so the smallest-applicable-set answer is always
    // unambiguous: negative -> Integer, zero -> Whole, positive -> Natural.
    final magnitude = rng.nextInt(range.min, range.max);
    final n = switch (rng.nextInt(0, 2)) {
      0 => -magnitude,
      1 => 0,
      _ => magnitude,
    };
    final correct = n < 0
        ? 'Integer (Z)'
        : n == 0
            ? 'Whole number (W)'
            : 'Natural number (N)';
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.numberClassification,
      questionText: language == AppLanguage.english
          ? 'What is the smallest number set that $n belongs to?'
          : '$n किस सबसे छोटे संख्या समूह से संबंधित है?',
      options: buildMcOptionsFromCandidates(
        correct,
        const [
          'Natural number (N)',
          'Whole number (W)',
          'Integer (Z)',
          'Rational number (Q)',
        ],
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: language == AppLanguage.english
          ? 'N = {1,2,3,...}, W = {0,1,2,...}, Z = {...,-1,0,1,...}, '
              'Q = any p/q.'
          : 'N = {1,2,3,...}, W = {0,1,2,...}, Z = {...,-1,0,1,...}, '
              'Q = कोई भी p/q.',
    );
  }

  static bool _isPrime(int n) {
    if (n < 2) return false;
    for (var i = 2; i * i <= n; i++) {
      if (n % i == 0) return false;
    }
    return true;
  }

  /// TUNABLE — larger numbers (more factors to check) at higher tiers.
  static ({int min, int max}) _rangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 20),
        2 => (min: 2, max: 50),
        3 => (min: 2, max: 100),
        _ => (min: 2, max: 200),
      };
}
