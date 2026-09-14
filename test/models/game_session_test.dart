import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/game_session.dart';
import 'package:brain_mantra/models/puzzle.dart';

GameSession roundTrip(GameSession session) {
  final encoded = jsonEncode(session.toJson());
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return GameSession.fromJson(decoded);
}

Puzzle _samplePuzzle(int seed) => Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.arithmetic,
      questionText: '$seed + $seed = ?',
      options: ['${seed * 2 - 1}', '${seed * 2}', '${seed * 2 + 1}', '99'],
      correctAnswer: seed * 2,
      difficultyTier: 1,
      timeLimitSeconds: 15,
    );

void main() {
  test('empty puzzlesAnswered/correctness round-trip to empty lists', () {
    final original = GameSession(
      startedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
      score: 0,
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: const [],
      correctness: const [],
      isDailyChallenge: false,
    );
    final decoded = roundTrip(original);
    expect(decoded.puzzlesAnswered, isEmpty);
    expect(decoded.correctness, isEmpty);
    expect(decoded, equals(original));
  });

  test('populated session with nested puzzles round-trips exactly', () {
    final puzzles = [_samplePuzzle(1), _samplePuzzle(2), _samplePuzzle(3)];
    final original = GameSession(
      startedAt: DateTime.utc(2026, 3, 15, 9, 30, 0),
      score: 150,
      comboMultiplier: 3,
      livesRemaining: 2,
      puzzlesAnswered: puzzles,
      correctness: const [true, true, false],
      isDailyChallenge: false,
    );
    final decoded = roundTrip(original);
    expect(decoded, equals(original));
    expect(decoded.puzzlesAnswered, equals(puzzles));
  });

  test('seedUsed is null for a non-daily-challenge session', () {
    final original = GameSession(
      startedAt: DateTime.utc(2026, 1, 1),
      score: 0,
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: const [],
      correctness: const [],
      isDailyChallenge: false,
    );
    expect(roundTrip(original).seedUsed, isNull);
  });

  test('seedUsed round-trips when isDailyChallenge is true', () {
    final original = GameSession(
      startedAt: DateTime.utc(2026, 9, 5),
      score: 40,
      comboMultiplier: 2,
      livesRemaining: 3,
      puzzlesAnswered: [_samplePuzzle(4)],
      correctness: const [true],
      isDailyChallenge: true,
      seedUsed: '2026-09-05',
    );
    final decoded = roundTrip(original);
    expect(decoded.seedUsed, equals('2026-09-05'));
    expect(decoded.isDailyChallenge, isTrue);
  });

  test('startedAt DateTime round-trips exactly', () {
    final startedAt = DateTime.utc(2026, 9, 5, 14, 23, 7, 500);
    final original = GameSession(
      startedAt: startedAt,
      score: 0,
      comboMultiplier: 1,
      livesRemaining: 3,
      puzzlesAnswered: const [],
      correctness: const [],
      isDailyChallenge: false,
    );
    expect(roundTrip(original).startedAt, equals(startedAt));
  });

  test('score/comboMultiplier/livesRemaining at 0 and typical values', () {
    for (final vals in [
      (score: 0, combo: 0, lives: 0),
      (score: 9999, combo: 8, lives: 3),
    ]) {
      final original = GameSession(
        startedAt: DateTime.utc(2026, 1, 1),
        score: vals.score,
        comboMultiplier: vals.combo,
        livesRemaining: vals.lives,
        puzzlesAnswered: const [],
        correctness: const [],
        isDailyChallenge: false,
      );
      final decoded = roundTrip(original);
      expect(decoded.score, equals(vals.score));
      expect(decoded.comboMultiplier, equals(vals.combo));
      expect(decoded.livesRemaining, equals(vals.lives));
    }
  });
}
