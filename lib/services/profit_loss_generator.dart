import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a profit/loss-percentage question. Cost price and percentage are
/// generated first (both always clean multiples), and the selling price is
/// *derived* from them — never generated independently and then reverse-
/// engineered — so the percentage is guaranteed exact, no rounding needed.
abstract final class ProfitLossGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final percentages = _percentagesForTier(tier);

    // Cost price always a multiple of 100, so `costPrice ~/ 100` is exact
    // — that's what keeps sellingPrice an exact integer below regardless
    // of which percentage gets picked.
    final costPrice = rng.nextInt(1, 20) * 100;
    final percent = percentages[rng.nextInt(0, percentages.length - 1)];
    final isProfit = rng.nextBool();
    final sellingPrice = isProfit
        ? costPrice + (costPrice ~/ 100) * percent
        : costPrice - (costPrice ~/ 100) * percent;

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.profitLoss,
      questionText: 'A shopkeeper buys an item for ₹$costPrice and sells it '
          "for ₹$sellingPrice. Find the ${isProfit ? 'profit' : 'loss'} %.",
      options: buildNumericMcOptions(percent, rng, spread: 10),
      correctAnswer: percent,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: tier >= 3
          ? '${isProfit ? 'Profit' : 'Loss'} % = '
              '(${isProfit ? 'SP − CP' : 'CP − SP'}) / CP × 100'
          : null,
    );
  }

  /// TUNABLE — initial defaults. Round, easy-to-reason-about percentages
  /// at low tiers; finer-grained ones at high tiers.
  static List<int> _percentagesForTier(int tier) => switch (tier) {
        1 => const [10, 20, 25, 50],
        2 => const [10, 15, 20, 25, 30, 50],
        3 => const [5, 10, 15, 20, 25, 30, 35, 40],
        _ => const [5, 8, 12, 15, 18, 22, 28, 35, 40, 45],
      };
}
