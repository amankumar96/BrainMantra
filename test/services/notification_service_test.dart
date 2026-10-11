import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/player_stats.dart';
import 'package:brain_mantra/services/notification_service.dart';

void main() {
  group('isDailyChallengeDoneToday', () {
    test('null lastDailyChallengeDate is not done', () {
      final result = NotificationService.isDailyChallengeDoneToday(
        PlayerStats(lastDailyChallengeDate: null),
        DateTime.utc(2026, 1, 1, 12),
      );
      expect(result, isFalse);
    });

    test('same UTC calendar day, different time, counts as done', () {
      final result = NotificationService.isDailyChallengeDoneToday(
        PlayerStats(lastDailyChallengeDate: DateTime.utc(2026, 1, 1, 1)),
        DateTime.utc(2026, 1, 1, 23),
      );
      expect(result, isTrue);
    });

    test('a day earlier is not done today', () {
      final result = NotificationService.isDailyChallengeDoneToday(
        PlayerStats(lastDailyChallengeDate: DateTime.utc(2025, 12, 31, 23)),
        DateTime.utc(2026, 1, 1, 0, 30),
      );
      expect(result, isFalse);
    });
  });

  group('dailyChallengeReminderTarget', () {
    test('before 18:00 and not done: schedules at 18:00 today', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final target = NotificationService.dailyChallengeReminderTarget(
        dailyChallengeDoneToday: false,
        now: now,
      );
      expect(target, equals(DateTime(2026, 1, 1, 18)));
    });

    test('already done today: null regardless of time', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final target = NotificationService.dailyChallengeReminderTarget(
        dailyChallengeDoneToday: true,
        now: now,
      );
      expect(target, isNull);
    });

    test('past 18:00 and not done: null (skipped for today, not shifted '
        'to tomorrow)', () {
      final now = DateTime(2026, 1, 1, 19, 0);
      final target = NotificationService.dailyChallengeReminderTarget(
        dailyChallengeDoneToday: false,
        now: now,
      );
      expect(target, isNull);
    });
  });

  group('streakWarningTarget', () {
    test('active streak, not done, before 20:00: schedules at 20:00 today',
        () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final target = NotificationService.streakWarningTarget(
        currentStreakDays: 5,
        dailyChallengeDoneToday: false,
        now: now,
      );
      expect(target, equals(DateTime(2026, 1, 1, 20)));
    });

    test('no active streak: null even if not done and before 20:00', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final target = NotificationService.streakWarningTarget(
        currentStreakDays: 0,
        dailyChallengeDoneToday: false,
        now: now,
      );
      expect(target, isNull);
    });

    test('already done today: null even with an active streak', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final target = NotificationService.streakWarningTarget(
        currentStreakDays: 5,
        dailyChallengeDoneToday: true,
        now: now,
      );
      expect(target, isNull);
    });

    test('past 20:00: null', () {
      final now = DateTime(2026, 1, 1, 21, 0);
      final target = NotificationService.streakWarningTarget(
        currentStreakDays: 5,
        dailyChallengeDoneToday: false,
        now: now,
      );
      expect(target, isNull);
    });
  });

  group('inactivityReminderTarget', () {
    test('never played (null lastPlayedDate): 3 days from now', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final target = NotificationService.inactivityReminderTarget(
        lastPlayedDate: null,
        now: now,
      );
      expect(target, equals(now.add(const Duration(days: 3))));
    });

    test('recently played: 3 days from lastPlayedDate, pushed further out '
        'by playing again', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final lastPlayed = DateTime(2026, 1, 5, 9, 0); // just now, basically
      final target = NotificationService.inactivityReminderTarget(
        lastPlayedDate: lastPlayed,
        now: now,
      );
      expect(target, equals(lastPlayed.add(const Duration(days: 3))));
    });

    test('already more than 3 days since lastPlayedDate: clamped to at '
        'least 3 days from now, never in the past', () {
      final now = DateTime(2026, 1, 10, 10, 0);
      final lastPlayed = DateTime(2026, 1, 1, 10, 0); // 9 days ago
      final target = NotificationService.inactivityReminderTarget(
        lastPlayedDate: lastPlayed,
        now: now,
      );
      expect(target.isAfter(now), isTrue);
      expect(target, equals(now.add(const Duration(days: 3))));
    });
  });
}
