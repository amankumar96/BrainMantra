import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/game_session.dart';
import 'package:math_blitz/models/player_stats.dart';
import 'package:math_blitz/models/puzzle.dart';
import 'package:math_blitz/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Route SharedPreferences to its mock in-memory backend for every test
  // — no real device/plugin channel is ever involved.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlayerStats save/load', () {
    test('save then load round-trips exactly, including a non-empty '
        'bestScoreByTier map', () async {
      final stats = PlayerStats(
        highScore: 500,
        currentStreakDays: 4,
        lastPlayedDate: DateTime.utc(2026, 9, 5),
        totalCoins: 120,
        bestScoreByTier: const {1: 100, 2: 250, 4: 900},
      );
      await StorageService.saveStats(stats);
      final loaded = await StorageService.loadStats();
      expect(loaded, equals(stats));
    });

    test('loading with nothing saved yet returns defaults, no exception',
        () async {
      final loaded = await StorageService.loadStats();
      expect(loaded, equals(PlayerStats()));
    });

    test('loading corrupted stored data returns defaults, no exception',
        () async {
      SharedPreferences.setMockInitialValues({
        'player_stats': 'this is not valid JSON {{{',
      });
      final loaded = await StorageService.loadStats();
      expect(loaded, equals(PlayerStats()));
    });

    test('a second save overwrites the first', () async {
      await StorageService.saveStats(PlayerStats(highScore: 10));
      await StorageService.saveStats(PlayerStats(highScore: 999));
      final loaded = await StorageService.loadStats();
      expect(loaded.highScore, equals(999));
    });
  });

  group('GameSession save', () {
    test('saveSession persists a JSON blob that decodes back to an '
        'identical GameSession', () async {
      final puzzle = Puzzle(
        category: PuzzleCategory.mathTest,
        type: PuzzleType.arithmetic,
        questionText: '2 + 2 = ?',
        options: const ['3', '4', '5', '6'],
        correctAnswer: 4,
        difficultyTier: 1,
        timeLimitSeconds: 15,
      );
      final session = GameSession(
        startedAt: DateTime.utc(2026, 9, 5, 10, 0, 0),
        score: 40,
        comboMultiplier: 2,
        livesRemaining: 3,
        puzzlesAnswered: [puzzle],
        correctness: const [true],
        isDailyChallenge: false,
      );

      await StorageService.saveSession(session);

      // StorageService's contract (per ARCHITECTURE.md) only specifies a
      // save, not a matching load — verify persistence by reading the raw
      // stored value back through SharedPreferences directly.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('last_session');
      expect(raw, isNotNull);
      final decoded =
          GameSession.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
      expect(decoded, equals(session));
    });
  });

  group('clearAll', () {
    test('removes both saved stats and the last session', () async {
      await StorageService.saveStats(PlayerStats(highScore: 42));
      final session = GameSession(
        startedAt: DateTime.utc(2026, 1, 1),
        score: 0,
        comboMultiplier: 1,
        livesRemaining: 3,
        puzzlesAnswered: const [],
        correctness: const [],
        isDailyChallenge: false,
      );
      await StorageService.saveSession(session);

      await StorageService.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('player_stats'), isNull);
      expect(prefs.getString('last_session'), isNull);
      // loadStats still behaves correctly (defaults) after clearing.
      expect(await StorageService.loadStats(), equals(PlayerStats()));
    });
  });

  group('hasSeenRules', () {
    test('defaults to false when nothing has been recorded yet', () async {
      expect(await StorageService.hasSeenRules(), isFalse);
    });

    test('markRulesSeen flips it to true and it stays true', () async {
      await StorageService.markRulesSeen();
      expect(await StorageService.hasSeenRules(), isTrue);
    });

    test('clearAll resets hasSeenRules back to false', () async {
      await StorageService.markRulesSeen();
      expect(await StorageService.hasSeenRules(), isTrue);

      await StorageService.clearAll();

      expect(await StorageService.hasSeenRules(), isFalse);
    });
  });
}
