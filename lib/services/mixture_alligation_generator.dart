import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Mixture & Alligation (Phase 11B, topic 18): the alligation cross-rule
/// — mixing a cheaper and a dearer ingredient to hit a target mean price.
/// The mean price is generated *between* x and y first (never chosen
/// independently), so the ratio always reduces to a clean, positive
/// fraction.
abstract final class MixtureAlligationGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final range = _rangeForTier(tier);
    final cheap = rng.nextInt(range.min, range.max);
    final dear = cheap + rng.nextInt(range.min, range.max);
    final mean = rng.nextInt(cheap + 1, dear - 1);

    final cheapShare = dear - mean;
    final dearShare = mean - cheap;
    final g = gcd(cheapShare, dearShare);
    final correct = '${cheapShare ~/ g}:${dearShare ~/ g}';

    final candidates = {
      correct,
      '$cheapShare:$dearShare',
      '${dearShare ~/ g}:${cheapShare ~/ g}',
      '${(cheapShare ~/ g) + 1}:${dearShare ~/ g}',
      '${cheapShare ~/ g}:${(dearShare ~/ g) + 1}',
    }..remove(correct);

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.mixtureAlligation,
      questionText: 'A shopkeeper mixes tea worth ₹$cheap/kg with tea '
          'worth ₹$dear/kg to get a mixture worth ₹$mean/kg. Find the '
          'ratio (cheaper : dearer) in which they should be mixed, in '
          'simplest form.',
      options: buildMcOptionsFromCandidates(correct, candidates.toList(), rng),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: 'Cheaper : Dearer = (Dearer price - Mean) : (Mean - Cheaper price)',
    );
  }

  static ({int min, int max}) _rangeForTier(int tier) => switch (tier) {
        1 => (min: 5, max: 15),
        2 => (min: 5, max: 25),
        3 => (min: 10, max: 40),
        _ => (min: 10, max: 60),
      };
}
