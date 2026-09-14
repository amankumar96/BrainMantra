import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/streak_service.dart';

void main() {
  group('nextStreakDays', () {
    test('first-ever play (lastPlayedDate null) starts the streak at 1', () {
      final result = StreakService.nextStreakDays(
        previousStreakDays: 0,
        lastPlayedDate: null,
        now: DateTime.utc(2026, 9, 6, 10, 0, 0),
      );
      expect(result, equals(1));
    });

    test('playing again the same UTC calendar day leaves the streak '
        'unchanged', () {
      final result = StreakService.nextStreakDays(
        previousStreakDays: 5,
        lastPlayedDate: DateTime.utc(2026, 9, 6, 1, 0, 0), // earlier today
        now: DateTime.utc(2026, 9, 6, 23, 0, 0), // later, still today
      );
      expect(result, equals(5));
    });

    test('exactly one UTC calendar day later increments the streak', () {
      final result = StreakService.nextStreakDays(
        previousStreakDays: 5,
        lastPlayedDate: DateTime.utc(2026, 9, 5, 23, 0, 0),
        now: DateTime.utc(2026, 9, 6, 0, 30, 0),
      );
      expect(result, equals(6));
    });

    test('a gap of 2+ UTC calendar days resets the streak to 1', () {
      final result = StreakService.nextStreakDays(
        previousStreakDays: 12,
        lastPlayedDate: DateTime.utc(2026, 9, 1),
        now: DateTime.utc(2026, 9, 6),
      );
      expect(result, equals(1));
    });

    test('a negative gap (defensive - clock skew/corrupted data) resets '
        'to 1 rather than crashing or going negative', () {
      final result = StreakService.nextStreakDays(
        previousStreakDays: 8,
        lastPlayedDate: DateTime.utc(2026, 9, 10), // "in the future"
        now: DateTime.utc(2026, 9, 6),
      );
      expect(result, equals(1));
    });

    test('comparisons use UTC calendar days, not local time - a local-time '
        'reading near UTC midnight does not falsely count as a different '
        'day', () {
      // 11:30pm local time in a UTC+2 zone is already the next UTC day
      // (1:30am UTC) - lastPlayedDate and now both expressed with an
      // explicit local offset that crosses the UTC boundary, to prove
      // .toUtc() normalization is actually happening, not comparing raw
      // local fields.
      final lastPlayed =
          DateTime.parse('2026-09-05T23:30:00+02:00'); // = 2026-09-05T21:30 UTC
      final now = DateTime.parse('2026-09-06T01:00:00+02:00'); // = 2026-09-05T23:00 UTC
      final result = StreakService.nextStreakDays(
        previousStreakDays: 3,
        lastPlayedDate: lastPlayed,
        now: now,
      );
      // Both instants fall on the same UTC calendar day (2026-09-05),
      // despite "now" being on 2026-09-06 in local time - unchanged, not
      // incremented.
      expect(result, equals(3));
    });

    test('same seed/inputs are fully deterministic (pure function, no '
        'hidden state)', () {
      final a = StreakService.nextStreakDays(
        previousStreakDays: 2,
        lastPlayedDate: DateTime.utc(2026, 9, 5),
        now: DateTime.utc(2026, 9, 6),
      );
      final b = StreakService.nextStreakDays(
        previousStreakDays: 2,
        lastPlayedDate: DateTime.utc(2026, 9, 5),
        now: DateTime.utc(2026, 9, 6),
      );
      expect(a, equals(b));
    });
  });
}
