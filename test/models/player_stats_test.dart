import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/player_stats.dart';

PlayerStats roundTrip(PlayerStats stats) {
  final encoded = jsonEncode(stats.toJson());
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return PlayerStats.fromJson(decoded);
}

void main() {
  test('lastPlayedDate null round-trips to null', () {
    final original = PlayerStats(
      highScore: 0,
      currentStreakDays: 0,
      lastPlayedDate: null,
      totalCoins: 0,
      bestScoreByTier: const {},
    );
    final decoded = roundTrip(original);
    expect(decoded.lastPlayedDate, isNull);
    expect(decoded, equals(original));
  });

  test('lastPlayedDate set round-trips exactly', () {
    final lastPlayed = DateTime.utc(2026, 9, 4, 8, 0, 0);
    final original = PlayerStats(lastPlayedDate: lastPlayed);
    final decoded = roundTrip(original);
    expect(decoded.lastPlayedDate, equals(lastPlayed));
  });

  test('bestScoreByTier empty map round-trips to an empty map', () {
    final original = PlayerStats(bestScoreByTier: const {});
    final decoded = roundTrip(original);
    expect(decoded.bestScoreByTier, isEmpty);
  });

  test('bestScoreByTier with multiple entries: keys decode back as int', () {
    final original = PlayerStats(
      bestScoreByTier: const {1: 100, 2: 250, 4: 900},
    );
    final decoded = roundTrip(original);
    expect(decoded.bestScoreByTier, equals({1: 100, 2: 250, 4: 900}));
    expect(decoded.bestScoreByTier.keys, everyElement(isA<int>()));
  });

  test('highScore/currentStreakDays/totalCoins at 0 and positive values', () {
    for (final vals in [
      (highScore: 0, streak: 0, coins: 0),
      (highScore: 123456, streak: 42, coins: 999),
    ]) {
      final original = PlayerStats(
        highScore: vals.highScore,
        currentStreakDays: vals.streak,
        totalCoins: vals.coins,
      );
      final decoded = roundTrip(original);
      expect(decoded.highScore, equals(vals.highScore));
      expect(decoded.currentStreakDays, equals(vals.streak));
      expect(decoded.totalCoins, equals(vals.coins));
    }
  });
}
