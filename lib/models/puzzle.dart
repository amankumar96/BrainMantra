import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'diagram_data.dart';

/// Top-level test category. Kept separate from [PuzzleType] so stats,
/// difficulty curves, and UI can branch on category cheaply without
/// inspecting every possible type value.
enum PuzzleCategory { mathTest, reasoningTest }

/// Flat, namespaced puzzle type. New reasoning sub-types (seating
/// arrangement, syllogism, pattern, ...) can be appended here later without
/// any structural change to [Puzzle] itself.
enum PuzzleType {
  // mathTest
  arithmetic,
  trueFalse,
  missingNumber,
  oddOneOut,
  sequence,
  targetNumber,
  // mathTest — expanded topic library (ROADMAP_PHASE2.md Phase 7)
  bodmas,
  speedDistance,
  profitLoss,
  interest,
  // mathTest — Geometry/Probability/Ratio topics, framed as real-life
  // word problems (no diagram — see perimeter_generator.dart,
  // probability_generator.dart, ratio_generator.dart)
  perimeter,
  probability,
  ratio,
  // mathTest — diagram-based (ROADMAP_PHASE2.md Phase 8, Stage 1: diagram
  // in the question body, options stay plain text)
  angleFinding,
  areaVolume,
  coordinateDistance,
  graphReading,
  // mathTest — Phase 11B, the 22-topic spec (math-game-question-
  // generators.md) grouped into related-formula generators, same "one
  // PuzzleType, several sub-cases" shape as areaVolume/ratio/probability.
  numberClassification,
  surds,
  algebraicIdentity,
  linearEquation,
  quadraticEquation,
  progression,
  trigRatio,
  mensurationAdvanced,
  coordinateGeometry,
  logarithm,
  permutationCombination,
  statistics,
  unitConversion,
  workTime,
  mixtureAlligation,
  // reasoningTest
  familyTree,
  shapeIdentification,
  // reasoningTest — Phase 12 (rebalance): text-based verbal/logical
  // reasoning topics, the same convention real reasoning tests use when
  // not rendering actual images — see mirror_image_generator.dart's doc
  // comment for why mirrorImage/paperFolding/figureSeries are textual
  // rather than rendered figures.
  mirrorImage,
  paperFolding,
  figureSeries,
  seatingArrangement,
  coding,
  directionSense,
  wordPuzzle,
  analogy,
  ranking,
  statementConclusion,
}

const _uuid = Uuid();

/// A short, friendly, single-line display name for [type] — shown as the
/// small topic badge on `game_screen.dart`'s question card. Purely
/// cosmetic (never affects generation/scoring); every case is a plain,
/// player-facing label for what the enum's own doc-comment groupings
/// above already say each type covers.
String topicLabel(PuzzleType type) => switch (type) {
  PuzzleType.arithmetic => 'Arithmetic',
  PuzzleType.trueFalse => 'True or False',
  PuzzleType.missingNumber => 'Missing Number',
  PuzzleType.oddOneOut => 'Odd One Out',
  PuzzleType.sequence => 'Number Sequence',
  PuzzleType.targetNumber => 'Target Number',
  PuzzleType.bodmas => 'BODMAS',
  PuzzleType.speedDistance => 'Speed & Distance',
  PuzzleType.profitLoss => 'Profit & Loss',
  PuzzleType.interest => 'Interest',
  PuzzleType.perimeter => 'Perimeter',
  PuzzleType.probability => 'Probability',
  PuzzleType.ratio => 'Ratio',
  PuzzleType.angleFinding => 'Angle Finding',
  PuzzleType.areaVolume => 'Area & Volume',
  PuzzleType.coordinateDistance => 'Coordinate Distance',
  PuzzleType.graphReading => 'Graph Reading',
  PuzzleType.numberClassification => 'Number Classification',
  PuzzleType.surds => 'Surds',
  PuzzleType.algebraicIdentity => 'Algebraic Identity',
  PuzzleType.linearEquation => 'Linear Equation',
  PuzzleType.quadraticEquation => 'Quadratic Equation',
  PuzzleType.progression => 'Progression',
  PuzzleType.trigRatio => 'Trigonometry',
  PuzzleType.mensurationAdvanced => 'Mensuration',
  PuzzleType.coordinateGeometry => 'Coordinate Geometry',
  PuzzleType.logarithm => 'Logarithm',
  PuzzleType.permutationCombination => 'Permutation & Combination',
  PuzzleType.statistics => 'Statistics',
  PuzzleType.unitConversion => 'Unit Conversion',
  PuzzleType.workTime => 'Work & Time',
  PuzzleType.mixtureAlligation => 'Mixture & Alligation',
  PuzzleType.familyTree => 'Family Tree',
  PuzzleType.shapeIdentification => 'Shape Identification',
  PuzzleType.mirrorImage => 'Mirror & Water Image',
  PuzzleType.paperFolding => 'Paper Folding',
  PuzzleType.figureSeries => 'Figure Series',
  PuzzleType.seatingArrangement => 'Seating Arrangement',
  PuzzleType.coding => 'Coding-Decoding',
  PuzzleType.directionSense => 'Direction Sense',
  PuzzleType.wordPuzzle => 'Word Puzzle',
  PuzzleType.analogy => 'Analogy',
  PuzzleType.ranking => 'Ranking',
  PuzzleType.statementConclusion => 'Statement & Conclusion',
};

/// A single question. Generic enough to represent both a math-test question
/// (e.g. "7 × 8 = ?") and a reasoning-test question (e.g. a family-tree
/// relationship or a shape-identification prompt) — both are just
/// questionText + options + a computed correctAnswer.
class Puzzle {
  final String id;
  final PuzzleCategory category;
  final PuzzleType type;
  final String questionText;
  final List<String> options;

  /// int, bool, or String depending on [type]. Never hardcoded — always
  /// computed at generation time by the service that builds this puzzle.
  final dynamic correctAnswer;
  final int difficultyTier;
  final int timeLimitSeconds;

  /// Non-null only for Phase 8 Stage 1 diagram-based types (angleFinding,
  /// areaVolume, coordinateDistance, graphReading) — the raw geometry a
  /// `DiagramPainter` renders. Null for every other puzzle type.
  final DiagramData? diagramData;

  /// A short formula/theorem-name nudge, populated at every tier (see
  /// ROADMAP_PHASE2.md's Phase 11 tier plan) — every generator that has a
  /// named formula behind it always sets this; only the handful of
  /// generators with no underlying formula (e.g. bare arithmetic,
  /// graph-reading) leave it null.
  final String? hint;

  /// Non-null only for Phase 13 diagram-as-answer-option types (e.g.
  /// mirrorImage's rendered sub-cases): one [DiagramData] per entry in
  /// [options], same length and same order — `options[i]` is the internal
  /// selection/correctness key for the shape drawn from
  /// `optionDiagrams[i]`. When this is set, the UI renders each option as
  /// a small diagram instead of `options[i]` as text (the id strings are
  /// never shown to the player). Null for every other puzzle type.
  final List<DiagramData>? optionDiagrams;

  Puzzle({
    String? id,
    required this.category,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.difficultyTier,
    required this.timeLimitSeconds,
    this.diagramData,
    this.hint,
    this.optionDiagrams,
  }) : assert(
         optionDiagrams == null || optionDiagrams.length == options.length,
         'optionDiagrams must be null or exactly one entry per option',
       ),
       id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'type': type.name,
    'questionText': questionText,
    'options': options,
    'correctAnswer': correctAnswer,
    'difficultyTier': difficultyTier,
    'timeLimitSeconds': timeLimitSeconds,
    'diagramData': diagramData?.toJson(),
    'hint': hint,
    'optionDiagrams': optionDiagrams?.map((d) => d.toJson()).toList(),
  };

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    final correctAnswer = json['correctAnswer'];
    if (correctAnswer is! int &&
        correctAnswer is! bool &&
        correctAnswer is! String) {
      throw FormatException(
        'Puzzle.correctAnswer must be int, bool, or String, '
        'got ${correctAnswer.runtimeType}',
      );
    }
    final diagramJson = json['diagramData'] as Map<String, dynamic>?;
    final optionDiagramsJson = json['optionDiagrams'] as List?;
    return Puzzle(
      id: json['id'] as String,
      category: PuzzleCategory.values.byName(json['category'] as String),
      type: PuzzleType.values.byName(json['type'] as String),
      questionText: json['questionText'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: correctAnswer,
      difficultyTier: json['difficultyTier'] as int,
      timeLimitSeconds: json['timeLimitSeconds'] as int,
      diagramData: diagramJson == null
          ? null
          : DiagramData.fromJson(diagramJson),
      hint: json['hint'] as String?,
      optionDiagrams: optionDiagramsJson
          ?.map((d) => DiagramData.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Puzzle &&
        other.id == id &&
        other.category == category &&
        other.type == type &&
        other.questionText == questionText &&
        listEquals(other.options, options) &&
        other.correctAnswer == correctAnswer &&
        other.difficultyTier == difficultyTier &&
        other.timeLimitSeconds == timeLimitSeconds &&
        other.diagramData == diagramData &&
        other.hint == hint &&
        listEquals(other.optionDiagrams, optionDiagrams);
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    type,
    questionText,
    Object.hashAll(options),
    correctAnswer,
    difficultyTier,
    timeLimitSeconds,
    diagramData,
    hint,
    optionDiagrams == null ? null : Object.hashAll(optionDiagrams!),
  );

  @override
  String toString() =>
      'Puzzle(id: $id, category: $category, type: $type, '
      'questionText: $questionText, options: $options, '
      'correctAnswer: $correctAnswer, difficultyTier: $difficultyTier, '
      'timeLimitSeconds: $timeLimitSeconds, diagramData: $diagramData, '
      'hint: $hint, optionDiagrams: $optionDiagrams)';
}
