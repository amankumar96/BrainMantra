import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Direction Sense (Phase 12, reasoning topic 6): straight-line
/// displacement distance after two perpendicular legs of a walk (legs
/// drawn from a Pythagorean triple, so the final distance is always an
/// exact integer, never a rounded √), and final-facing-direction after a
/// sequence of turns.
abstract final class DirectionSenseGenerator {
  static const _triples = [(3, 4, 5), (6, 8, 10), (5, 12, 13), (8, 15, 17)];
  static const _compass = ['North', 'East', 'South', 'West'];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _displacement(tier, params.timeLimitSeconds, rng)
        : _facing(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _displacement(int tier, int timeLimitSeconds, RngService rng) {
    final (leg1, leg2, hyp) = _triples[rng.nextInt(0, _triples.length - 1)];
    // Pick two perpendicular directions (e.g. North then East).
    final startDir = rng.nextInt(0, 3);
    final turnRight = rng.nextBool();
    final secondDir = (startDir + (turnRight ? 1 : 3)) % 4;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.directionSense,
      questionText: 'A person walks $leg1 km towards ${_compass[startDir]}, '
          'then turns ${turnRight ? 'right' : 'left'} and walks $leg2 km '
          'towards ${_compass[secondDir]}. How far is the person from the '
          'starting point (straight-line distance)?',
      options: buildNumericMcOptions(hyp, rng, spread: 3),
      correctAnswer: hyp,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'The two legs are perpendicular — use the Pythagorean theorem.',
    );
  }

  static Puzzle _facing(int tier, int timeLimitSeconds, RngService rng) {
    final turnCount = switch (tier) {
      1 => 2,
      2 => 3,
      3 => 4,
      _ => 5,
    };
    var facing = rng.nextInt(0, 3);
    final startName = _compass[facing];
    final turns = <String>[];
    for (var i = 0; i < turnCount; i++) {
      final clockwise = rng.nextBool();
      // Only ever 90° or 180° turns, matching how this puzzle type is
      // conventionally phrased.
      final isHalfTurn = rng.nextBool();
      final steps = isHalfTurn ? 2 : 1;
      facing = (facing + (clockwise ? steps : -steps) + 4) % 4;
      turns.add(isHalfTurn ? 'turns 180°' : 'turns ${clockwise ? 'right' : 'left'}');
    }
    final correct = _compass[facing];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.directionSense,
      questionText: 'A person starts facing $startName, then '
          '${turns.join(', then ')}. Which direction are they facing now?',
      options: buildMcOptionsFromCandidates(
        correct,
        _compass.where((d) => d != correct).toList(),
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Track 90°/180° turns clockwise (right) or counter-clockwise (left).',
    );
  }
}
