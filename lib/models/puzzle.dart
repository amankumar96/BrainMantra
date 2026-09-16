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
  // reasoningTest
  familyTree,
  shapeIdentification,
}

const _uuid = Uuid();

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
  }) : id = id ?? _uuid.v4();

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
    return Puzzle(
      id: json['id'] as String,
      category: PuzzleCategory.values.byName(json['category'] as String),
      type: PuzzleType.values.byName(json['type'] as String),
      questionText: json['questionText'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: correctAnswer,
      difficultyTier: json['difficultyTier'] as int,
      timeLimitSeconds: json['timeLimitSeconds'] as int,
      diagramData: diagramJson == null ? null : DiagramData.fromJson(diagramJson),
      hint: json['hint'] as String?,
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
        other.hint == hint;
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
      );

  @override
  String toString() =>
      'Puzzle(id: $id, category: $category, type: $type, '
      'questionText: $questionText, options: $options, '
      'correctAnswer: $correctAnswer, difficultyTier: $difficultyTier, '
      'timeLimitSeconds: $timeLimitSeconds, diagramData: $diagramData, '
      'hint: $hint)';
}
