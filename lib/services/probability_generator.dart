import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a probability question — rolling a fair die, drawing a colored
/// ball from a bag, or drawing a card from a standard deck (picked at
/// random each call). The answer is always a reduced fraction string
/// (e.g. `"1/3"`), computed from generated favourable/total outcome
/// counts, never a decimal — fractions are how probability is actually
/// taught at this level, and reducing via [gcd] keeps a single answer
/// exact instead of rounded.
abstract final class ProbabilityGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);

    return switch (rng.nextInt(0, 2)) {
      0 => _die(tier, params.timeLimitSeconds, rng),
      1 => _bagOfBalls(tier, params.timeLimitSeconds, rng),
      _ => _deckOfCards(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _die(int tier, int timeLimitSeconds, RngService rng) {
    // "greater than N" for N in 1-5, out of the 6 faces of a fair die.
    final threshold = rng.nextInt(1, 5);
    final favourable = 6 - threshold; // faces strictly greater than threshold
    return _build(
      tier: tier,
      timeLimitSeconds: timeLimitSeconds,
      questionText: 'You roll a fair six-sided die once. What is the '
          'probability of rolling a number greater than $threshold?',
      favourable: favourable,
      total: 6,
      rng: rng,
    );
  }

  static Puzzle _bagOfBalls(int tier, int timeLimitSeconds, RngService rng) {
    final red = rng.nextInt(1, 6);
    final blue = rng.nextInt(1, 6);
    final green = rng.nextInt(1, 6);
    final total = red + blue + green;
    return _build(
      tier: tier,
      timeLimitSeconds: timeLimitSeconds,
      questionText: 'A bag contains $red red, $blue blue and $green green '
          'balls. If you pick one ball at random, what is the probability '
          "it's red?",
      favourable: red,
      total: total,
      rng: rng,
    );
  }

  static Puzzle _deckOfCards(int tier, int timeLimitSeconds, RngService rng) {
    // A standard 52-card deck: 4 suits of 13, or 12 face cards (jack,
    // queen, king x4 suits) — both real, commonly-taught scenarios.
    final wantsSuit = rng.nextBool();
    final favourable = wantsSuit ? 13 : 12;
    final label = wantsSuit ? 'a heart' : 'a face card (jack, queen, or king)';
    return _build(
      tier: tier,
      timeLimitSeconds: timeLimitSeconds,
      questionText: 'A standard deck of 52 playing cards is shuffled. What '
          'is the probability of drawing $label?',
      favourable: favourable,
      total: 52,
      rng: rng,
    );
  }

  static Puzzle _build({
    required int tier,
    required int timeLimitSeconds,
    required String questionText,
    required int favourable,
    required int total,
    required RngService rng,
  }) {
    final correct = _reduce(favourable, total);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.probability,
      questionText: questionText,
      options: _buildFractionOptions(favourable, total, correct, rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Probability = favourable outcomes ÷ total outcomes',
    );
  }

  /// Reduces `favourable/total` to its simplest fraction form.
  static String _reduce(int favourable, int total) {
    final divisor = gcd(favourable, total);
    return '${favourable ~/ divisor}/${total ~/ divisor}';
  }

  /// Builds 4 shuffled, unique fraction-string options: [correct] plus 3
  /// distractors built from common real mistakes — mixing up favourable
  /// with unfavourable (the complement), and off-by-one favourable/total
  /// counts — each independently reduced the same way as the correct
  /// answer, so a distractor never accidentally collides with it.
  static List<String> _buildFractionOptions(
    int favourable,
    int total,
    String correct,
    RngService rng,
  ) {
    final candidates = <String>{};
    void tryAdd(int f, int t) {
      if (t <= 0 || f < 0 || f > t) return;
      final reduced = _reduce(f, t);
      if (reduced != correct) candidates.add(reduced);
    }

    tryAdd(total - favourable, total); // complement — the classic mix-up
    tryAdd(favourable - 1, total);
    tryAdd(favourable + 1, total);
    tryAdd(favourable, total - 1);
    tryAdd(favourable, total + 1);
    tryAdd(favourable - 1, total - 1);
    tryAdd(favourable + 1, total + 1);

    // Defensive fallback if the above somehow didn't yield 3 unique
    // distractors (should be unreachable given the spread of transforms
    // above, but this must never throw or hang mid-fuzz-test): count up
    // through total+2, total+3, ... until enough distinct reduced
    // fractions exist.
    var extraTotal = total + 2;
    while (candidates.length < 3) {
      tryAdd(favourable, extraTotal);
      extraTotal++;
    }

    final pool = candidates.toList();
    shuffleList(pool, rng);
    final options = [correct, ...pool.take(3)];
    shuffleList(options, rng);
    return options;
  }
}
