import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Progressions — AP & GP (Phase 11B, topic 6): nth term and sum for an
/// arithmetic progression, nth term for a geometric one.
abstract final class ProgressionGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return switch (rng.nextInt(0, 2)) {
      0 => _apNthTerm(tier, params.timeLimitSeconds, rng),
      1 => _apSum(tier, params.timeLimitSeconds, rng),
      _ => _gpNthTerm(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _apNthTerm(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final a = rng.nextInt(1, range.maxStart);
    final d = rng.nextInt(1, range.maxStep);
    final n = rng.nextInt(3, range.maxN);
    final answer = a + (n - 1) * d;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.progression,
      questionText: 'An AP starts at $a with common difference $d. '
          'Find its ${n}th term.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'aₙ = a + (n-1)d',
    );
  }

  static Puzzle _apSum(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    final a = rng.nextInt(1, range.maxStart);
    final d = rng.nextInt(1, range.maxStep);
    // n picked even so n/2 is always a whole number - keeps Sₙ an exact
    // integer without needing to check 2a+(n-1)d's parity separately.
    final n = rng.nextInt(2, range.maxN ~/ 2) * 2;
    final answer = (n ~/ 2) * (2 * a + (n - 1) * d);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.progression,
      questionText: 'An AP starts at $a with common difference $d. '
          'Find the sum of its first $n terms.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Sₙ = n/2 × [2a + (n-1)d]',
    );
  }

  static Puzzle _gpNthTerm(int tier, int timeLimitSeconds, RngService rng) {
    final a = rng.nextInt(1, tier <= 2 ? 5 : 8);
    final r = rng.nextInt(2, tier <= 2 ? 3 : 4);
    final n = rng.nextInt(3, tier <= 2 ? 4 : 5); // kept small: rⁿ⁻¹ grows fast
    var answer = a;
    for (var i = 1; i < n; i++) {
      answer *= r;
    }
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.progression,
      questionText: 'A GP starts at $a with common ratio $r. '
          'Find its ${n}th term.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'aₙ = a × rⁿ⁻¹',
    );
  }

  static int _spreadFor(int answer) => (answer * 0.2).round().clamp(2, 200);

  static ({int maxStart, int maxStep, int maxN}) _rangeForTier(int tier) =>
      switch (tier) {
        1 => (maxStart: 10, maxStep: 5, maxN: 8),
        2 => (maxStart: 15, maxStep: 8, maxN: 10),
        3 => (maxStart: 20, maxStep: 10, maxN: 14),
        _ => (maxStart: 25, maxStep: 12, maxN: 18),
      };
}
