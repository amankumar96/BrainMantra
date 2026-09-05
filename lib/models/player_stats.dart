import 'package:flutter/foundation.dart';

/// Persisted, cross-session player progress.
class PlayerStats {
  final int highScore;
  final int currentStreakDays;
  final DateTime? lastPlayedDate;
  final int totalCoins;

  /// Best score achieved at each difficulty tier (1..4).
  final Map<int, int> bestScoreByTier;

  PlayerStats({
    this.highScore = 0,
    this.currentStreakDays = 0,
    this.lastPlayedDate,
    this.totalCoins = 0,
    this.bestScoreByTier = const {},
  });

  Map<String, dynamic> toJson() => {
        'highScore': highScore,
        'currentStreakDays': currentStreakDays,
        'lastPlayedDate': lastPlayedDate?.toIso8601String(),
        'totalCoins': totalCoins,
        // JSON object keys must be strings; converted back in fromJson.
        'bestScoreByTier':
            bestScoreByTier.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final lastPlayedRaw = json['lastPlayedDate'] as String?;
    final bestScoreRaw =
        (json['bestScoreByTier'] as Map).cast<String, dynamic>();
    return PlayerStats(
      highScore: json['highScore'] as int,
      currentStreakDays: json['currentStreakDays'] as int,
      lastPlayedDate:
          lastPlayedRaw == null ? null : DateTime.parse(lastPlayedRaw),
      totalCoins: json['totalCoins'] as int,
      bestScoreByTier:
          bestScoreRaw.map((k, v) => MapEntry(int.parse(k), v as int)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerStats &&
        other.highScore == highScore &&
        other.currentStreakDays == currentStreakDays &&
        other.lastPlayedDate == lastPlayedDate &&
        other.totalCoins == totalCoins &&
        mapEquals(other.bestScoreByTier, bestScoreByTier);
  }

  @override
  int get hashCode => Object.hash(
        highScore,
        currentStreakDays,
        lastPlayedDate,
        totalCoins,
        Object.hashAllUnordered(
          bestScoreByTier.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'PlayerStats(highScore: $highScore, '
      'currentStreakDays: $currentStreakDays, '
      'lastPlayedDate: $lastPlayedDate, totalCoins: $totalCoins, '
      'bestScoreByTier: $bestScoreByTier)';
}
