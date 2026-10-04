import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/daily_challenge_lock.dart';

void main() {
  group('isLocked', () {
    test('never played (null lastPlayedDate) is never locked', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: null,
        now: DateTime.utc(2026, 1, 1),
      );
      expect(result, isFalse);
    });

    test('just played is locked', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: last,
        now: last.add(const Duration(minutes: 1)),
      );
      expect(result, isTrue);
    });

    test('just under 24 hours is still locked', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: last,
        now: last.add(const Duration(hours: 23, minutes: 59)),
      );
      expect(result, isTrue);
    });

    test('exactly 24 hours later is unlocked', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: last,
        now: last.add(const Duration(hours: 24)),
      );
      expect(result, isFalse);
    });

    test('well past 24 hours is unlocked', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: last,
        now: last.add(const Duration(days: 3)),
      );
      expect(result, isFalse);
    });
  });

  group('remaining', () {
    test('never played returns Duration.zero', () {
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: null,
        now: DateTime.utc(2026, 1, 1),
      );
      expect(result, equals(Duration.zero));
    });

    test('already unlocked returns Duration.zero', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: last,
        now: last.add(const Duration(hours: 25)),
      );
      expect(result, equals(Duration.zero));
    });

    test('mid-lock returns exactly the time left, never negative', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: last,
        now: last.add(const Duration(hours: 10)),
      );
      expect(result, equals(const Duration(hours: 14)));
    });
  });
}
