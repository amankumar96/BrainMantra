import 'package:flutter/foundation.dart';

import 'puzzle.dart';

/// One play session — either a free-play run or a daily challenge.
class GameSession {
  final DateTime startedAt;
  final int score;
  final int comboMultiplier;
  final int livesRemaining;
  final List<Puzzle> puzzlesAnswered;

  /// Parallel array to [puzzlesAnswered]: correctness[i] is whether
  /// puzzlesAnswered[i] was answered correctly.
  final List<bool> correctness;
  final bool isDailyChallenge;

  /// Only set when [isDailyChallenge] is true — the date-derived seed used
  /// to generate this session's puzzles deterministically.
  final String? seedUsed;

  GameSession({
    required this.startedAt,
    required this.score,
    required this.comboMultiplier,
    required this.livesRemaining,
    required this.puzzlesAnswered,
    required this.correctness,
    required this.isDailyChallenge,
    this.seedUsed,
  });

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'score': score,
        'comboMultiplier': comboMultiplier,
        'livesRemaining': livesRemaining,
        'puzzlesAnswered': puzzlesAnswered.map((p) => p.toJson()).toList(),
        'correctness': correctness,
        'isDailyChallenge': isDailyChallenge,
        'seedUsed': seedUsed,
      };

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      startedAt: DateTime.parse(json['startedAt'] as String),
      score: json['score'] as int,
      comboMultiplier: json['comboMultiplier'] as int,
      livesRemaining: json['livesRemaining'] as int,
      puzzlesAnswered: (json['puzzlesAnswered'] as List)
          .map((e) => Puzzle.fromJson(e as Map<String, dynamic>))
          .toList(),
      correctness: List<bool>.from(json['correctness'] as List),
      isDailyChallenge: json['isDailyChallenge'] as bool,
      seedUsed: json['seedUsed'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameSession &&
        other.startedAt == startedAt &&
        other.score == score &&
        other.comboMultiplier == comboMultiplier &&
        other.livesRemaining == livesRemaining &&
        listEquals(other.puzzlesAnswered, puzzlesAnswered) &&
        listEquals(other.correctness, correctness) &&
        other.isDailyChallenge == isDailyChallenge &&
        other.seedUsed == seedUsed;
  }

  @override
  int get hashCode => Object.hash(
        startedAt,
        score,
        comboMultiplier,
        livesRemaining,
        Object.hashAll(puzzlesAnswered),
        Object.hashAll(correctness),
        isDailyChallenge,
        seedUsed,
      );

  @override
  String toString() =>
      'GameSession(startedAt: $startedAt, score: $score, '
      'comboMultiplier: $comboMultiplier, livesRemaining: $livesRemaining, '
      'puzzlesAnswered: ${puzzlesAnswered.length} items, '
      'correctness: $correctness, isDailyChallenge: $isDailyChallenge, '
      'seedUsed: $seedUsed)';
}
