import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// A shape and how many sides it has — real geometric fact, not a puzzle
/// answer. The generator below uses this table to *derive* a question's
/// correct answer fresh each time, the same way `expression_evaluator`
/// encodes arithmetic rules rather than caching specific results.
class ShapeInfo {
  final String name;
  final int sides;
  const ShapeInfo(this.name, this.sides);
}

/// The full set of shapes this generator can ask about. Deliberately
/// always fully in play regardless of tier — see [_pickWeightedShape] —
/// so there's always enough variety to avoid accidental duplicate
/// questions, even at tier 1.
const List<ShapeInfo> _shapePool = [
  ShapeInfo('triangle', 3),
  ShapeInfo('square', 4),
  ShapeInfo('pentagon', 5),
  ShapeInfo('hexagon', 6),
  ShapeInfo('heptagon', 7),
  ShapeInfo('octagon', 8),
  ShapeInfo('nonagon', 9),
  ShapeInfo('decagon', 10),
];

/// Builds a shape-identification [Puzzle] — one of the two starting
/// reasoning-category question types (alongside family-tree questions).
abstract final class ShapeReasoningGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final shape = _pickWeightedShape(params.reasoning, rng);

    // Two equally-likely phrasings, so the puzzle type isn't repetitive:
    // ask for the side count (numeric answer) or ask which shape matches
    // a given side count (name answer).
    // Decide the phrasing (and consume the options' randomness) before
    // drawing the id, so the id draw doesn't have to be duplicated in
    // both branches below.
    final askForSideCount = rng.nextBool();
    final questionText = askForSideCount
        ? 'How many sides does a ${shape.name} have?'
        : 'Which shape has ${shape.sides} sides?';
    final options = askForSideCount
        ? _sideCountOptions(shape, rng)
        : _shapeNameOptions(shape, rng);
    final correctAnswer = askForSideCount ? shape.sides : shape.name;

    return Puzzle(
      // Deterministic id — see deterministicId's dartdoc for why this
      // matters (Daily Challenge fairness).
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.shapeIdentification,
      questionText: questionText,
      options: options,
      correctAnswer: correctAnswer,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
    );
  }

  /// Picks a shape from the full pool, weighting shapes inside the tier's
  /// [ReasoningParams.shapeMinSides]..[ReasoningParams.shapeMaxSides]
  /// range 3x more likely than shapes outside it — so easy tiers mostly
  /// (but not exclusively) ask about simple shapes, without narrowing the
  /// pool enough to make repeat questions likely.
  static ShapeInfo _pickWeightedShape(ReasoningParams params, RngService rng) {
    final weights = _shapePool
        .map((shape) => (shape.sides >= params.shapeMinSides &&
                shape.sides <= params.shapeMaxSides)
            ? 3
            : 1)
        .toList();
    final totalWeight = weights.reduce((a, b) => a + b);

    var roll = rng.nextInt(0, totalWeight - 1);
    for (var i = 0; i < _shapePool.length; i++) {
      if (roll < weights[i]) return _shapePool[i];
      roll -= weights[i];
    }
    return _shapePool.last; // unreachable given the loop covers all weight
  }

  /// Builds 4 unique numeric options for a "how many sides" question:
  /// [target]'s real side count plus 3 other real shapes' side counts
  /// (every pool entry has a distinct side count, so this can't collide).
  static List<String> _sideCountOptions(ShapeInfo target, RngService rng) {
    final distractorPool = _shapePool
        .where((shape) => shape.sides != target.sides)
        .toList();
    shuffleList(distractorPool, rng);
    final options = [target.sides, ...distractorPool.take(3).map((s) => s.sides)]
        .map((sides) => sides.toString())
        .toList();
    shuffleList(options, rng);
    return options;
  }

  /// Builds 4 unique name options for a "which shape has N sides" question.
  static List<String> _shapeNameOptions(ShapeInfo target, RngService rng) {
    final distractorPool = _shapePool
        .where((shape) => shape.name != target.name)
        .toList();
    shuffleList(distractorPool, rng);
    final options = [
      target.name,
      ...distractorPool.take(3).map((s) => s.name),
    ];
    shuffleList(options, rng);
    return options;
  }
}
