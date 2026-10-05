import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/daily_challenge_lock.dart';

void main() {
  group('isLocked', () {
    test('never played (null lastPlayedDate) is never locked', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: null,
        now: DateTime(2026, 1, 1, 14),
      );
      expect(result, isFalse);
    });

    test('played today after the 10 AM reset: locked for the rest of '
        'the day', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: DateTime(2026, 1, 1, 10, 30),
        now: DateTime(2026, 1, 1, 23),
      );
      expect(result, isTrue);
    });

    test('played right at the reset boundary (10:00:00) is locked', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: DateTime(2026, 1, 1, 10),
        now: DateTime(2026, 1, 1, 10),
      );
      expect(result, isTrue);
    });

    test(
        'played yesterday afternoon, now past today\'s reset: unlocked '
        '(a new day\'s challenge is available)', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: DateTime(2026, 1, 1, 15),
        now: DateTime(2026, 1, 2, 11),
      );
      expect(result, isFalse);
    });

    test(
        "played yesterday afternoon, now before today's reset (e.g. "
        '9 AM): still locked — today\'s reset hasn\'t happened yet', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: DateTime(2026, 1, 1, 15),
        now: DateTime(2026, 1, 2, 9),
      );
      expect(result, isTrue);
    });

    test('played just before midnight, checked just after midnight '
        '(still before 10 AM): still locked — the reset is at 10 AM, '
        'not midnight', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: DateTime(2026, 1, 1, 23, 50),
        now: DateTime(2026, 1, 2, 0, 10),
      );
      expect(result, isTrue);
    });

    test('played many days ago is unlocked', () {
      final result = DailyChallengeLock.isLocked(
        lastPlayedDate: DateTime(2026, 1, 1, 11),
        now: DateTime(2026, 1, 5, 14),
      );
      expect(result, isFalse);
    });
  });

  group('remaining', () {
    test('never played returns Duration.zero', () {
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: null,
        now: DateTime(2026, 1, 1, 14),
      );
      expect(result, equals(Duration.zero));
    });

    test('already unlocked returns Duration.zero', () {
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: DateTime(2026, 1, 1, 15),
        now: DateTime(2026, 1, 2, 11),
      );
      expect(result, equals(Duration.zero));
    });

    test('played at noon: exactly 22 hours remain until 10 AM tomorrow',
        () {
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: DateTime(2026, 1, 1, 12),
        now: DateTime(2026, 1, 1, 12),
      );
      expect(result, equals(const Duration(hours: 22)));
    });

    test('mid-lock: remaining shrinks as "now" advances toward the next '
        'reset', () {
      final result = DailyChallengeLock.remaining(
        lastPlayedDate: DateTime(2026, 1, 1, 10),
        now: DateTime(2026, 1, 2, 8),
      );
      expect(result, equals(const Duration(hours: 2)));
    });
  });
}
