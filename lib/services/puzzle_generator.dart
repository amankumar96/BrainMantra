import '../models/puzzle.dart';
import 'angle_finding_generator.dart';
import 'area_volume_generator.dart';
import 'bodmas_generator.dart';
import 'coordinate_distance_generator.dart';
import 'difficulty_curve.dart';
import 'family_tree_generator.dart';
import 'graph_reading_generator.dart';
import 'interest_generator.dart';
import 'profit_loss_generator.dart';
import 'puzzle_generator_basic_math.dart';
import 'puzzle_generator_odd_one_out.dart';
import 'puzzle_generator_sequence_target.dart';
import 'relationship_resolver.dart';
import 'rng_service.dart';
import 'rng_utils.dart';
import 'shape_reasoning_generator.dart';
import 'speed_distance_generator.dart';

/// The single "front door" for building a puzzle: "give me a puzzle of
/// this [PuzzleType] at this difficulty tier". Routes to the right
/// generator — either one of the 6 math functions (in
/// puzzle_generator_basic_math.dart / puzzle_generator_pattern_math.dart)
/// or one of the 2 reasoning generators (family tree, built below; shape
/// identification, in shape_reasoning_generator.dart).
abstract final class PuzzleGenerator {
  static Puzzle generate({
    required int tier,
    required PuzzleType type,
    required RngService rng,
  }) {
    return switch (type) {
      PuzzleType.arithmetic => generateArithmetic(tier, rng),
      PuzzleType.trueFalse => generateTrueFalse(tier, rng),
      PuzzleType.missingNumber => generateMissingNumber(tier, rng),
      PuzzleType.oddOneOut => generateOddOneOut(tier, rng),
      PuzzleType.sequence => generateSequence(tier, rng),
      PuzzleType.targetNumber => generateTargetNumber(tier, rng),
      PuzzleType.bodmas => BodmasGenerator.generate(tier: tier, rng: rng),
      PuzzleType.speedDistance =>
        SpeedDistanceGenerator.generate(tier: tier, rng: rng),
      PuzzleType.profitLoss =>
        ProfitLossGenerator.generate(tier: tier, rng: rng),
      PuzzleType.interest => InterestGenerator.generate(tier: tier, rng: rng),
      PuzzleType.angleFinding =>
        AngleFindingGenerator.generate(tier: tier, rng: rng),
      PuzzleType.areaVolume =>
        AreaVolumeGenerator.generate(tier: tier, rng: rng),
      PuzzleType.coordinateDistance =>
        CoordinateDistanceGenerator.generate(tier: tier, rng: rng),
      PuzzleType.graphReading =>
        GraphReadingGenerator.generate(tier: tier, rng: rng),
      PuzzleType.familyTree => _generateFamilyTree(tier, rng),
      PuzzleType.shapeIdentification =>
        ShapeReasoningGenerator.generate(tier: tier, rng: rng),
    };
  }
}

/// Every English relationship term [RelationshipResolver] can produce —
/// used as the distractor pool for a family-tree question's wrong
/// options, so a distractor is always a real, plausible relationship
/// term, never a nonsense string.
const List<String> _relationshipVocabulary = [
  'father', 'mother', 'son', 'daughter', 'brother', 'sister',
  'grandfather', 'grandmother', 'grandson', 'granddaughter',
  'uncle', 'aunt', 'nephew', 'niece', 'cousin',
  'husband', 'wife',
  'father-in-law', 'mother-in-law', 'son-in-law', 'daughter-in-law',
  'brother-in-law', 'sister-in-law',
  'great-grandfather', 'great-grandmother',
  'great-grandson', 'great-granddaughter',
  'grand-uncle', 'grand-aunt', 'grand-nephew', 'grand-niece',
];

/// Builds a family-tree relationship question: generate a random tree,
/// pick two people in it, and ask "how is A related to B?" — with the
/// answer computed by [RelationshipResolver], never hardcoded.
Puzzle _generateFamilyTree(int tier, RngService rng) {
  final timeLimitSeconds = DifficultyCurve.paramsForTier(tier).timeLimitSeconds;
  final tree = FamilyTreeGenerator.generate(tier: tier, rng: rng);

  // Not every random pair of people has a relationship in the resolver's
  // vocabulary (they might be too many generations apart, or two
  // unrelated in-laws with no covered composition) — retrying is the
  // expected, normal path here, not an error condition.
  const maxAttempts = 300;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (tree.people.length < 2) break; // can't happen given tier params, but be safe
    final fromIndex = rng.nextInt(0, tree.people.length - 1);
    final toIndex = rng.nextInt(0, tree.people.length - 1);
    if (fromIndex == toIndex) continue;

    final fromId = tree.people[fromIndex].id;
    final toId = tree.people[toIndex].id;
    try {
      final correctTerm =
          RelationshipResolver.resolve(tree, fromId: fromId, toId: toId);
      final narration =
          RelationshipResolver.narrate(tree, fromId: fromId, toId: toId);
      final fromName = tree.byId(fromId).name;
      final toName = tree.byId(toId).name;

      return Puzzle(
        id: deterministicId(rng),
        category: PuzzleCategory.reasoningTest,
        type: PuzzleType.familyTree,
        questionText:
            '${narration.join(' ')} How is $fromName related to $toName?',
        options: buildMcOptionsFromCandidates(
          correctTerm,
          _relationshipVocabulary,
          rng,
        ),
        correctAnswer: correctTerm,
        difficultyTier: tier,
        timeLimitSeconds: timeLimitSeconds,
      );
    } on NoRelationFoundException {
      continue; // try a different pair
    }
  }

  // Should be unreachable in practice: with at least 4 people even at
  // tier 1 (root couple + >=2 children), plenty of resolvable pairs
  // exist (siblings, parent/child). Throwing rather than silently
  // returning a malformed puzzle if it's ever somehow exhausted.
  throw StateError(
    'Could not build a family-tree puzzle after $maxAttempts attempts '
    '(tier $tier)',
  );
}

