import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Trigonometry & Trigonometric Identities (Phase 11B, topics 7 & 13):
/// standard-angle ratio lookups, the Pythagorean identity applied to a
/// Pythagorean triple (keeps every ratio an exact fraction, never an
/// irrational decimal), and — tier 3-4 — the double-angle sine formula
/// on the same triples.
abstract final class TrigRatioGenerator {
  // TUNABLE — standard angle table. 90° omitted for tan (undefined).
  static const _standardTable = {
    '0': {'sin': '0', 'cos': '1', 'tan': '0'},
    '30': {'sin': '1/2', 'cos': '√3/2', 'tan': '1/√3'},
    '45': {'sin': '1/√2', 'cos': '1/√2', 'tan': '1'},
    '60': {'sin': '√3/2', 'cos': '1/2', 'tan': '√3'},
    '90': {'sin': '1', 'cos': '0'},
  };

  // (opposite, adjacent, hypotenuse) — every ratio here is an exact
  // fraction, so sinθ/cosθ/sin2θ never need rounding.
  static const _triples = [(3, 4, 5), (5, 12, 13), (8, 15, 17), (7, 24, 25)];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    if (tier >= 3 && rng.nextBool()) {
      return _doubleAngle(tier, params.timeLimitSeconds, rng);
    }
    return rng.nextBool()
        ? _standardLookup(tier, params.timeLimitSeconds, rng)
        : _pythagoreanIdentity(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _standardLookup(int tier, int timeLimitSeconds, RngService rng) {
    final angles = _standardTable.keys.toList();
    final angle = angles[rng.nextInt(0, angles.length - 1)];
    final ratios = _standardTable[angle]!.keys.toList();
    final ratio = ratios[rng.nextInt(0, ratios.length - 1)];
    final correct = _standardTable[angle]![ratio]!;
    final allValues = _standardTable.values
        .expand((m) => m.values)
        .toSet()
        .toList();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.trigRatio,
      questionText: 'What is $ratio($angle°)?',
      options: buildMcOptionsFromCandidates(correct, allValues, rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Standard angle table: sin30°=1/2, tan45°=1, cos60°=1/2, ...',
    );
  }

  static Puzzle _pythagoreanIdentity(
    int tier,
    int timeLimitSeconds,
    RngService rng,
  ) {
    final (opp, adj, hyp) = _triples[rng.nextInt(0, _triples.length - 1)];
    final knowSin = rng.nextBool();
    final correct = knowSin ? '$adj/$hyp' : '$opp/$hyp';
    final candidates = {
      '$opp/$hyp',
      '$adj/$hyp',
      '$opp/$adj',
      '$adj/$opp',
      '$hyp/$opp',
      '$hyp/$adj',
    };
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.trigRatio,
      questionText: knowSin
          ? 'sinθ = $opp/$hyp. Using sin²θ + cos²θ = 1, find cosθ.'
          : 'cosθ = $adj/$hyp. Using sin²θ + cos²θ = 1, find sinθ.',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'sin²θ + cos²θ = 1',
    );
  }

  static Puzzle _doubleAngle(int tier, int timeLimitSeconds, RngService rng) {
    final (opp, adj, hyp) = _triples[rng.nextInt(0, _triples.length - 1)];
    // sin2θ = 2 sinθ cosθ = 2·opp·adj / hyp² — reduced to lowest terms.
    final num = 2 * opp * adj;
    final den = hyp * hyp;
    final g = gcd(num, den);
    final correct = '${num ~/ g}/${den ~/ g}';
    final candidates = {
      '$num/$den',
      '${opp * adj}/$den',
      '$num/${hyp * opp}',
      correct,
      '${num ~/ g}/${(den ~/ g) + 1}',
    }..remove(correct);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.trigRatio,
      questionText: 'sinθ = $opp/$hyp and cosθ = $adj/$hyp. '
          'Using sin2θ = 2sinθcosθ, find sin2θ (lowest terms).',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'sin2θ = 2 sinθ cosθ',
    );
  }
}
