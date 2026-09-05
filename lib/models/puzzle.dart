import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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

  Puzzle({
    String? id,
    required this.category,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.difficultyTier,
    required this.timeLimitSeconds,
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
    return Puzzle(
      id: json['id'] as String,
      category: PuzzleCategory.values.byName(json['category'] as String),
      type: PuzzleType.values.byName(json['type'] as String),
      questionText: json['questionText'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: correctAnswer,
      difficultyTier: json['difficultyTier'] as int,
      timeLimitSeconds: json['timeLimitSeconds'] as int,
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
        other.timeLimitSeconds == timeLimitSeconds;
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
      );

  @override
  String toString() =>
      'Puzzle(id: $id, category: $category, type: $type, '
      'questionText: $questionText, options: $options, '
      'correctAnswer: $correctAnswer, difficultyTier: $difficultyTier, '
      'timeLimitSeconds: $timeLimitSeconds)';
}
