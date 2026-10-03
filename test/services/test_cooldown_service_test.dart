import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/age_group.dart';
import 'package:brain_mantra/services/test_cooldown_service.dart';

void main() {
  group('canAttempt', () {
    test('never attempted (no entry for this age group) is always allowed',
        () {
      final result = TestCooldownService.canAttempt(
        ageGroup: AgeGroup.thirteenPlus,
        lastAttempt: const {},
        now: DateTime.utc(2026, 1, 1, 12),
      );
      expect(result, isTrue);
    });

    test('exactly at the 2-hour mark is allowed', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = TestCooldownService.canAttempt(
        ageGroup: AgeGroup.sixteenPlus,
        lastAttempt: {'sixteenPlus': last},
        now: last.add(const Duration(hours: 2)),
      );
      expect(result, isTrue);
    });

    test('just under 2 hours since the last attempt is blocked', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = TestCooldownService.canAttempt(
        ageGroup: AgeGroup.eighteenPlus,
        lastAttempt: {'eighteenPlus': last},
        now: last.add(const Duration(hours: 1, minutes: 59)),
      );
      expect(result, isFalse);
    });

    test('only checks the matching age group\'s own entry', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = TestCooldownService.canAttempt(
        ageGroup: AgeGroup.thirteenPlus,
        lastAttempt: {'sixteenPlus': last}, // a different age group
        now: last,
      );
      expect(result, isTrue);
    });
  });

  group('remaining', () {
    test('never attempted returns Duration.zero', () {
      final result = TestCooldownService.remaining(
        ageGroup: AgeGroup.thirteenPlus,
        lastAttempt: const {},
        now: DateTime.utc(2026, 1, 1),
      );
      expect(result, equals(Duration.zero));
    });

    test('already due (cooldown elapsed) returns Duration.zero', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = TestCooldownService.remaining(
        ageGroup: AgeGroup.thirteenPlus,
        lastAttempt: {'thirteenPlus': last},
        now: last.add(const Duration(hours: 3)),
      );
      expect(result, equals(Duration.zero));
    });

    test('mid-cooldown returns exactly the time left, never negative', () {
      final last = DateTime.utc(2026, 1, 1, 10);
      final result = TestCooldownService.remaining(
        ageGroup: AgeGroup.thirteenPlus,
        lastAttempt: {'thirteenPlus': last},
        now: last.add(const Duration(minutes: 45)),
      );
      expect(result, equals(const Duration(hours: 1, minutes: 15)));
    });
  });
}
