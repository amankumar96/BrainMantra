import 'puzzle.dart';

/// The three age-tiered "Test" cards on Home — distinct from Play/Daily
/// Challenge's open-ended scoring: each is a fixed 30-question, pass/fail
/// Test drawn from a maths-only pool scoped to roughly this age's NCERT
/// curriculum level. See the feature plan's NCERT topic-mapping table for
/// why each [mathPool] contains exactly the types it does.
enum AgeGroup {
  thirteenPlus,
  sixteenPlus,
  eighteenPlus;

  /// "13+" / "16+" / "18+", for the Home card label.
  String get label => switch (this) {
    AgeGroup.thirteenPlus => '13+',
    AgeGroup.sixteenPlus => '16+',
    AgeGroup.eighteenPlus => '18+',
  };

  /// The maths-only topic pool this Test draws from — null for 18+, which
  /// deliberately reuses Play mode's own full pool/tier logic rather than
  /// duplicating that list here and risking the two drifting apart (see
  /// [GameController]'s ageGroupTest handling).
  List<PuzzleType>? get mathPool => switch (this) {
    AgeGroup.thirteenPlus => thirteenPlusPool,
    AgeGroup.sixteenPlus => sixteenPlusPool,
    AgeGroup.eighteenPlus => null,
  };
}

/// Class 10 topics only — the genuine NCERT chapter matches, not every
/// chapter (Triangles & Similarity, Circles & Tangents, Applications of
/// Trigonometry have no matching generator and are deliberately left out).
const List<PuzzleType> thirteenPlusPool = [
  PuzzleType.numberClassification, // Real Numbers
  PuzzleType.algebraicIdentity, // Polynomials
  PuzzleType.linearEquation, // Pair of Linear Equations
  PuzzleType.quadraticEquation, // Quadratic Equations
  PuzzleType.progression, // Arithmetic Progressions
  PuzzleType.coordinateGeometry, // Coordinate Geometry
  PuzzleType.trigRatio, // Trigonometric Ratios
  PuzzleType.areaVolume, // Surface Areas & Volumes
  PuzzleType.mensurationAdvanced, // Surface Areas & Volumes / Areas Related to Circles
  PuzzleType.statistics, // Statistics
  PuzzleType.probability, // Probability
];

/// The 13+ pool plus every other existing math PuzzleType mapping to
/// Class 6-9 content, plus permutationCombination (Class 11-12, already
/// has a generator) — i.e. the entire math library except the three
/// Class 1-5-level basics (arithmetic, trueFalse, missingNumber), which
/// are too easy for a teen/adult curriculum test.
const List<PuzzleType> sixteenPlusPool = [
  ...thirteenPlusPool,
  PuzzleType.bodmas,
  PuzzleType.ratio,
  PuzzleType.profitLoss,
  PuzzleType.interest,
  PuzzleType.perimeter,
  PuzzleType.angleFinding,
  PuzzleType.speedDistance,
  PuzzleType.surds,
  PuzzleType.unitConversion,
  PuzzleType.workTime,
  PuzzleType.mixtureAlligation,
  PuzzleType.logarithm,
  PuzzleType.oddOneOut,
  PuzzleType.sequence,
  PuzzleType.targetNumber,
  PuzzleType.permutationCombination,
];
