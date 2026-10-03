import 'package:flutter/foundation.dart';

/// Persisted, cross-session player progress.
class PlayerStats {
  final int highScore;
  final int currentStreakDays;
  final DateTime? lastPlayedDate;
  final int totalCoins;

  /// Best score achieved at each difficulty tier (1..4).
  final Map<int, int> bestScoreByTier;

  /// Set whenever a Daily Challenge session ends (`game_screen.dart`'s
  /// `_persistAndShowResults`) — source of truth for "has today's Daily
  /// Challenge already been done," which `NotificationService` uses to
  /// skip that reminder once it has.
  final DateTime? lastDailyChallengeDate;

  /// When each Age-Group Test was last attempted, keyed by
  /// `AgeGroup.name` — source of truth for `TestCooldownService`'s
  /// 2-hour-per-age-group gate. Absent keys mean "never attempted."
  final Map<String, DateTime> lastAgeGroupTestAttempt;

  PlayerStats({
    this.highScore = 0,
    this.currentStreakDays = 0,
    this.lastPlayedDate,
    this.totalCoins = 0,
    this.bestScoreByTier = const {},
    this.lastDailyChallengeDate,
    this.lastAgeGroupTestAttempt = const {},
  });

  Map<String, dynamic> toJson() => {
        'highScore': highScore,
        'currentStreakDays': currentStreakDays,
        'lastPlayedDate': lastPlayedDate?.toIso8601String(),
        'totalCoins': totalCoins,
        // JSON object keys must be strings; converted back in fromJson.
        'bestScoreByTier':
            bestScoreByTier.map((k, v) => MapEntry(k.toString(), v)),
        'lastDailyChallengeDate': lastDailyChallengeDate?.toIso8601String(),
        'lastAgeGroupTestAttempt': lastAgeGroupTestAttempt
            .map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final lastPlayedRaw = json['lastPlayedDate'] as String?;
    final bestScoreRaw =
        (json['bestScoreByTier'] as Map).cast<String, dynamic>();
    // Both new fields are read defensively (absent = not yet in this
    // player's persisted JSON, from before this feature existed) rather
    // than assumed present, unlike the older fields above.
    final lastDailyChallengeRaw = json['lastDailyChallengeDate'] as String?;
    final lastAgeGroupTestRaw =
        (json['lastAgeGroupTestAttempt'] as Map?)?.cast<String, dynamic>();
    return PlayerStats(
      highScore: json['highScore'] as int,
      currentStreakDays: json['currentStreakDays'] as int,
      lastPlayedDate:
          lastPlayedRaw == null ? null : DateTime.parse(lastPlayedRaw),
      totalCoins: json['totalCoins'] as int,
      bestScoreByTier:
          bestScoreRaw.map((k, v) => MapEntry(int.parse(k), v as int)),
      lastDailyChallengeDate: lastDailyChallengeRaw == null
          ? null
          : DateTime.parse(lastDailyChallengeRaw),
      lastAgeGroupTestAttempt: lastAgeGroupTestRaw == null
          ? const {}
          : lastAgeGroupTestRaw
              .map((k, v) => MapEntry(k, DateTime.parse(v as String))),
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
        mapEquals(other.bestScoreByTier, bestScoreByTier) &&
        other.lastDailyChallengeDate == lastDailyChallengeDate &&
        mapEquals(other.lastAgeGroupTestAttempt, lastAgeGroupTestAttempt);
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
        lastDailyChallengeDate,
        Object.hashAllUnordered(
          lastAgeGroupTestAttempt.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'PlayerStats(highScore: $highScore, '
      'currentStreakDays: $currentStreakDays, '
      'lastPlayedDate: $lastPlayedDate, totalCoins: $totalCoins, '
      'bestScoreByTier: $bestScoreByTier, '
      'lastDailyChallengeDate: $lastDailyChallengeDate, '
      'lastAgeGroupTestAttempt: $lastAgeGroupTestAttempt)';
}
