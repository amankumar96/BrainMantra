import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/diagram_data.dart';
import 'package:math_blitz/models/puzzle.dart';

/// Round-trips [puzzle] through a *real* jsonEncode/jsonDecode boundary —
/// not just fromJson(toJson()) in memory — so a type-preservation bug in
/// `correctAnswer` (int vs bool vs String) would actually be caught.
Puzzle roundTrip(Puzzle puzzle) {
  final encoded = jsonEncode(puzzle.toJson());
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return Puzzle.fromJson(decoded);
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

void main() {
  group('Puzzle round-trip per type', () {
    final cases = <Puzzle>[
      Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.arithmetic,
        questionText: '7 × 8 = ?',
        options: const ['48', '54', '56', '64'],
        correctAnswer: 56,
        difficultyTier: 1,
        timeLimitSeconds: 15,
      ),
      Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.trueFalse,
        questionText: '9 + 10 = 21',
        options: const ['True', 'False'],
        correctAnswer: false,
        difficultyTier: 1,
        timeLimitSeconds: 10,
      ),
      Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.missingNumber,
        questionText: '12 + ? = 20',
        options: const ['6', '7', '8', '9'],
        correctAnswer: 8,
        difficultyTier: 2,
        timeLimitSeconds: 15,
      ),
      Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.oddOneOut,
        questionText: 'Which does not belong? 2, 4, 6, 9',
        options: const ['2', '4', '6', '9'],
        correctAnswer: '9',
        difficultyTier: 2,
        timeLimitSeconds: 20,
      ),
      Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.sequence,
        questionText: '2, 4, 6, 8, ?',
        options: const ['9', '10', '11', '12'],
        correctAnswer: 10,
        difficultyTier: 3,
        timeLimitSeconds: 20,
      ),
      Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.targetNumber,
        questionText: 'Make 24 using 3, 4, 6, 8',
        options: const [],
        correctAnswer: 24,
        difficultyTier: 4,
        timeLimitSeconds: 30,
      ),
      Puzzle(
        category: PuzzleCategory.reasoningTest,
        type: PuzzleType.familyTree,
        questionText:
            "If A is B's father and B is C's son, how is A related to C?",
        options: const ['Father', 'Grandfather', 'Uncle', 'Brother'],
        correctAnswer: 'Grandfather',
        difficultyTier: 3,
        timeLimitSeconds: 25,
      ),
      Puzzle(
        category: PuzzleCategory.reasoningTest,
        type: PuzzleType.shapeIdentification,
        questionText: 'Which shape has exactly 5 sides?',
        options: const ['Square', 'Pentagon', 'Hexagon', 'Triangle'],
        correctAnswer: 'Pentagon',
        difficultyTier: 1,
        timeLimitSeconds: 15,
      ),
    ];

    for (final original in cases) {
      test('${original.category.name}/${original.type.name} round-trips '
          'value and runtime type', () {
        final decoded = roundTrip(original);
        expect(decoded, equals(original));
        expect(decoded.correctAnswer.runtimeType,
            equals(original.correctAnswer.runtimeType));
      });
    }
  });

  test('empty options list round-trips to an empty list, not null', () {
    final original = Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.targetNumber,
      questionText: 'Make 10',
      options: const [],
      correctAnswer: 10,
      difficultyTier: 2,
      timeLimitSeconds: 20,
    );
    final decoded = roundTrip(original);
    expect(decoded.options, isEmpty);
    expect(decoded, equals(original));
  });

  test('difficultyTier boundary values 1 and 4 round-trip', () {
    for (final tier in [1, 4]) {
      final original = Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.arithmetic,
        questionText: '1 + 1',
        options: const ['1', '2', '3', '4'],
        correctAnswer: 2,
        difficultyTier: tier,
        timeLimitSeconds: 15,
      );
      expect(roundTrip(original).difficultyTier, equals(tier));
    }
  });

  test('auto-generated id is a non-empty, syntactically valid UUID', () {
    final puzzle = Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.arithmetic,
      questionText: '1 + 1',
      options: const ['1', '2', '3', '4'],
      correctAnswer: 2,
      difficultyTier: 1,
      timeLimitSeconds: 15,
    );
    expect(puzzle.id, isNotEmpty);
    expect(_uuidPattern.hasMatch(puzzle.id), isTrue,
        reason: '${puzzle.id} is not a valid UUID v4');
  });

  test('diagramData and hint round-trip through a real JSON boundary', () {
    final original = Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.angleFinding,
      questionText: "Two angles of a triangle are 50° and 65°. Find the third.",
      options: const ['55', '60', '65', '70'],
      correctAnswer: 65,
      difficultyTier: 4,
      timeLimitSeconds: 1800,
      diagramData: const DiagramData(
        kind: DiagramKind.triangle,
        angles: [50, 65, 65],
        unknownAngleIndex: 2,
      ),
      hint: 'Angle Sum Property: angles of a triangle add to 180°',
    );
    final decoded = roundTrip(original);
    expect(decoded, equals(original));
    expect(decoded.diagramData, equals(original.diagramData));
    expect(decoded.hint, equals(original.hint));
  });

  test('diagramData and hint are null when absent, not a decode error', () {
    final original = Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.arithmetic,
      questionText: '1 + 1',
      options: const ['1', '2', '3', '4'],
      correctAnswer: 2,
      difficultyTier: 1,
      timeLimitSeconds: 15,
    );
    final decoded = roundTrip(original);
    expect(decoded.diagramData, isNull);
    expect(decoded.hint, isNull);
  });

  test('fromJson throws on an unrecognized type string', () {
    final json = {
      'id': 'test-id',
      'category': 'mathTest',
      'type': 'notARealType',
      'questionText': 'x',
      'options': <String>[],
      'correctAnswer': 1,
      'difficultyTier': 1,
      'timeLimitSeconds': 10,
    };
    expect(() => Puzzle.fromJson(json), throwsArgumentError);
  });

  test('fromJson throws on an unrecognized category string', () {
    final json = {
      'id': 'test-id',
      'category': 'notARealCategory',
      'type': 'arithmetic',
      'questionText': 'x',
      'options': <String>[],
      'correctAnswer': 1,
      'difficultyTier': 1,
      'timeLimitSeconds': 10,
    };
    expect(() => Puzzle.fromJson(json), throwsArgumentError);
  });
}
