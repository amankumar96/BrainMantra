import 'dart:math' show sqrt;

import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// "Which does not belong? 2, 4, 6, 9" — 3 numbers satisfying a rule, plus
/// one that provably doesn't. The rule pool is tier-gated: simple
/// multiples-of/even-ness at tier 1-2, perfect squares/primes at tier 3-4.
Puzzle generateOddOneOut(int tier, RngService rng) {
  final params = DifficultyCurve.paramsForTier(tier);
  final useAdvancedRule = tier >= 3;
  final rule = !useAdvancedRule
      ? _OddOneOutRule.multiplesOfK
      : (rng.nextBool() ? _OddOneOutRule.perfectSquare : _OddOneOutRule.prime);
  final multipleK = rule == _OddOneOutRule.multiplesOfK
      ? [2, 3, 5][rng.nextInt(0, 2)]
      : 0;
  final upperBound = (params.math.maxOperand * 3).clamp(20, 400);

  bool satisfies(int n) => switch (rule) {
        _OddOneOutRule.multiplesOfK => n % multipleK == 0,
        _OddOneOutRule.perfectSquare => _isPerfectSquare(n),
        _OddOneOutRule.prime => _isPrime(n),
      };

  // Draws 3 distinct numbers that satisfy the rule.
  final matching = <int>{};
  var attempts = 0;
  while (matching.length < 3 && attempts < 1000) {
    attempts++;
    final n = rng.nextInt(2, upperBound);
    if (satisfies(n)) matching.add(n);
  }

  // Draws one number that provably does NOT satisfy the rule — regenerate
  // if a random draw accidentally also satisfies it, per ARCHITECTURE.md's
  // "regenerate the odd one if it accidentally also fits" requirement.
  int oddOne;
  attempts = 0;
  do {
    attempts++;
    final n = rng.nextInt(2, upperBound);
    oddOne = !satisfies(n) && !matching.contains(n)
        ? n
        : (attempts >= 60 ? _guaranteedNonMatch(rule, multipleK) : -1);
  } while (oddOne == -1);

  final options = [...matching, oddOne].map((n) => n.toString()).toList();
  shuffleList(options, rng);

  return Puzzle(
    id: deterministicId(rng),
    category: PuzzleCategory.mathTest,
    type: PuzzleType.oddOneOut,
    questionText: 'Which does not belong? ${options.join(", ")}',
    options: options,
    correctAnswer: oddOne.toString(),
    difficultyTier: tier,
    timeLimitSeconds: params.timeLimitSeconds,
  );
}

enum _OddOneOutRule { multiplesOfK, perfectSquare, prime }

bool _isPerfectSquare(int n) {
  if (n < 0) return false;
  // sqrt() can round to a slightly-off double right at a perfect-square
  // boundary, so check a +/-1 neighborhood of the rounded root rather
  // than trusting it exactly.
  final approxRoot = sqrt(n.toDouble()).round();
  for (final root in [approxRoot - 1, approxRoot, approxRoot + 1]) {
    if (root >= 0 && root * root == n) return true;
  }
  return false;
}

bool _isPrime(int n) {
  if (n < 2) return false;
  if (n % 2 == 0) return n == 2;
  for (var i = 3; i * i <= n; i += 2) {
    if (n % i == 0) return false;
  }
  return true;
}

/// A value provably outside the given rule, used only if 60 random draws
/// somehow failed to find a natural non-match (astronomically unlikely
/// given the ranges this generator uses, but must never throw or hang).
int _guaranteedNonMatch(_OddOneOutRule rule, int multipleK) => switch (rule) {
      // k+1 is never itself a multiple of k, for any k >= 2.
      _OddOneOutRule.multiplesOfK => multipleK + 1,
      // 7 is prime, and no prime greater than 1 is ever a perfect square.
      _OddOneOutRule.perfectSquare => 7,
      // 4 is composite (2x2), so it's never prime.
      _OddOneOutRule.prime => 4,
    };
