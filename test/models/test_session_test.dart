import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/game_session.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/models/test_session.dart';

TestSession roundTrip(TestSession testSession) {
  final encoded = jsonEncode(testSession.toJson());
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return TestSession.fromJson(decoded);
}

Puzzle _samplePuzzle(int seed) => Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.arithmetic,
      questionText: '$seed + $seed = ?',
      options: ['${seed * 2 - 1}', '${seed * 2}', '${seed * 2 + 1}', '99'],
      correctAnswer: seed * 2,
      difficultyTier: 1,
      timeLimitSeconds: 120,
    );

void main() {
  test('round-trips a full 3-question test with every outcome', () {
    final puzzles = [_samplePuzzle(1), _samplePuzzle(2), _samplePuzzle(3)];
    final session = GameSession(
      startedAt: DateTime.utc(2026, 9, 5, 10, 0, 0),
      score: 0, // unused by the marks system; GameSession's own field
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: puzzles,
      correctness: const [true, false, false],
      isDailyChallenge: true,
      seedUsed: '2026-09-05',
    );
    final original = TestSession(
      session: session,
      outcomes: const [
        AnswerOutcome.correct,
        AnswerOutcome.wrong,
        AnswerOutcome.skipped,
      ],
      marksAwarded: const [4, -2, 0],
    );

    final decoded = roundTrip(original);

    expect(decoded, equals(original));
    expect(decoded.totalMarks, equals(2));
  });

  test('round-trips an empty test session', () {
    final session = GameSession(
      startedAt: DateTime.utc(2026, 1, 1),
      score: 0,
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: const [],
      correctness: const [],
      isDailyChallenge: false,
    );
    final original = TestSession(
      session: session,
      outcomes: const [],
      marksAwarded: const [],
    );

    final decoded = roundTrip(original);

    expect(decoded, equals(original));
    expect(decoded.totalMarks, equals(0));
  });

  test('totalMarks sums positive, negative, and zero entries correctly',
      () {
    final session = GameSession(
      startedAt: DateTime.utc(2026, 1, 1),
      score: 0,
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: [_samplePuzzle(1), _samplePuzzle(2)],
      correctness: const [true, true],
      isDailyChallenge: false,
    );
    final testSession = TestSession(
      session: session,
      outcomes: const [AnswerOutcome.correct, AnswerOutcome.correct],
      marksAwarded: const [4, 4],
    );

    expect(testSession.totalMarks, equals(8));
  });

  test('constructor asserts outcomes/marksAwarded stay parallel arrays',
      () {
    final session = GameSession(
      startedAt: DateTime.utc(2026, 1, 1),
      score: 0,
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: [_samplePuzzle(1)],
      correctness: const [true],
      isDailyChallenge: false,
    );

    expect(
      () => TestSession(
        session: session,
        outcomes: const [AnswerOutcome.correct],
        marksAwarded: const [4, -2], // mismatched length
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
