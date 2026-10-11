import '../models/app_language.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'name_pool.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a ratio/proportion question — scaling a recipe, sharing money
/// between two people in a given ratio, or reading a map's scale (picked
/// at random each call). Every sub-case is constructed so the answer is
/// always an exact integer, never a rounded one — the scale factor (or
/// share count) is generated first and the rest derived from it, the same
/// "generate the clean number, derive everything else" rule
/// `ProfitLossGenerator` already follows.
abstract final class RatioGenerator {
  static Puzzle generate({
    required int tier,
    required RngService rng,
    required AppLanguage language,
  }) {
    final params = DifficultyCurve.paramsForTier(tier);

    return switch (rng.nextInt(0, 2)) {
      0 => _recipeScaling(tier, params.timeLimitSeconds, rng, language),
      1 => _sharingMoney(tier, params.timeLimitSeconds, rng, language),
      _ => _mapScale(tier, params.timeLimitSeconds, rng, language),
    };
  }

  static Puzzle _recipeScaling(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final servesRange = _servesRangeForTier(tier);
    final baseServes = rng.nextInt(servesRange.min, servesRange.max);
    final baseCups = rng.nextInt(2, 12);
    // Scale by a clean integer factor so the new cup amount is always
    // exact — never a fraction of a cup.
    final factor = rng.nextInt(2, 4);
    final newServes = baseServes * factor;
    final newCups = baseCups * factor;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.ratio,
      questionText: language == AppLanguage.english
          ? 'A recipe for $baseServes people needs $baseCups cups of '
              'flour. How many cups of flour are needed to make the same '
              'recipe for $newServes people?'
          : '$baseServes लोगों के लिए एक रेसिपी में $baseCups कप आटा '
              'चाहिए। उतनी ही रेसिपी $newServes लोगों के लिए बनाने में '
              'कितने कप आटा चाहिए?',
      options: buildNumericMcOptions(newCups, rng, spread: _spreadFor(newCups)),
      correctAnswer: newCups,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: language == AppLanguage.english
          ? 'Keep the ratio the same: new amount = old amount × '
              '(new servings ÷ old servings)'
          : 'अनुपात वही रखें: नई मात्रा = पुरानी मात्रा × '
              '(नए लोग ÷ पुराने लोग)',
    );
  }

  static Puzzle _sharingMoney(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final shareRange = _shareRangeForTier(tier);
    final share1 = rng.nextInt(1, shareRange.max);
    final share2 = rng.nextInt(1, shareRange.max);
    final unit = rng.nextInt(shareRange.min, shareRange.max) * 10;
    final total = (share1 + share2) * unit;
    final amount1 = share1 * unit;
    // Random distinct names every question — previously hardcoded
    // "Ravi"/"Sita" always, which is a repetition bug: see NamePool's doc
    // comment.
    final names = NamePool.pickDistinct(2, rng);
    final name1 = names[0];
    final name2 = names[1];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.ratio,
      questionText: language == AppLanguage.english
          ? '₹$total is shared between $name1 and $name2 in the '
              'ratio $share1:$share2. How much money does $name1 get?'
          : '₹$total को $name1 और $name2 के बीच $share1:$share2 के '
              'अनुपात में बांटा गया है। $name1 को कितना पैसा मिलेगा?',
      options:
          buildNumericMcOptions(amount1, rng, spread: _spreadFor(amount1)),
      correctAnswer: amount1,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: language == AppLanguage.english
          ? 'Split the total into (first share + second share) equal '
              "parts, then multiply by each person's share"
          : 'कुल राशि को (पहला भाग + दूसरा भाग) बराबर हिस्सों में बांटें, '
              'फिर हर व्यक्ति के भाग से गुणा करें',
    );
  }

  static Puzzle _mapScale(
    int tier,
    int timeLimitSeconds,
    RngService rng,
    AppLanguage language,
  ) {
    final scaleRange = _scaleRangeForTier(tier);
    final kmPerCm = rng.nextInt(scaleRange.min, scaleRange.max);
    final mapDistanceCm = rng.nextInt(2, 15);
    final actualDistanceKm = kmPerCm * mapDistanceCm;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.ratio,
      questionText: language == AppLanguage.english
          ? 'On a map, 1 cm represents $kmPerCm km. If two towns are '
              '$mapDistanceCm cm apart on the map, what is the actual '
              'distance between them?'
          : 'एक नक्शे पर, 1 सेमी $kmPerCm किमी के बराबर है। यदि नक्शे पर '
              'दो शहर $mapDistanceCm सेमी दूर हैं, तो उनके बीच की वास्तविक '
              'दूरी कितनी है?',
      options: buildNumericMcOptions(actualDistanceKm, rng,
          spread: _spreadFor(actualDistanceKm)),
      correctAnswer: actualDistanceKm,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: language == AppLanguage.english
          ? 'Actual distance = map distance × scale (km per cm)'
          : 'वास्तविक दूरी = नक्शे की दूरी × स्केल (किमी प्रति सेमी)',
    );
  }

  static int _spreadFor(int answer) => (answer * 0.25).round().clamp(2, 200);

  /// TUNABLE — initial defaults.
  static ({int min, int max}) _servesRangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 4),
        2 => (min: 2, max: 6),
        3 => (min: 3, max: 8),
        _ => (min: 3, max: 10),
      };

  static ({int min, int max}) _shareRangeForTier(int tier) => switch (tier) {
        1 => (min: 1, max: 4),
        2 => (min: 1, max: 6),
        3 => (min: 1, max: 8),
        _ => (min: 1, max: 10),
      };

  static ({int min, int max}) _scaleRangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 5),
        2 => (min: 2, max: 10),
        3 => (min: 5, max: 20),
        _ => (min: 5, max: 40),
      };
}
