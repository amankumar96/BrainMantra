import '../models/age_group.dart';

/// Enforces the 2-hour-per-age-group gate between Age-Group Test
/// attempts. Pure and stateless — no `StorageService` dependency — so
/// it's fully unit-testable with injected dates, matching the house
/// pattern (`streak_service.dart`, `difficulty_curve.dart`).
///
/// Local-only (no server enforcement) for v1 — same soft-enforcement
/// precedent Daily Challenge already sets (its "once a day" isn't
/// actually enforced server-side either), per the feature plan.
abstract final class TestCooldownService {
  static const Duration cooldown = Duration(hours: 2);

  /// Whether [ageGroup] can be attempted right [now], given when it was
  /// last attempted (null = never attempted → always allowed).
  static bool canAttempt({
    required AgeGroup ageGroup,
    required Map<String, DateTime> lastAttempt,
    required DateTime now,
  }) {
    final last = lastAttempt[ageGroup.name];
    if (last == null) return true;
    return now.difference(last) >= cooldown;
  }

  /// How much longer until [ageGroup] can be attempted again — [Duration.zero]
  /// if it's already due (or was never attempted). Never negative.
  static Duration remaining({
    required AgeGroup ageGroup,
    required Map<String, DateTime> lastAttempt,
    required DateTime now,
  }) {
    final last = lastAttempt[ageGroup.name];
    if (last == null) return Duration.zero;
    final elapsed = now.difference(last);
    if (elapsed >= cooldown) return Duration.zero;
    return cooldown - elapsed;
  }
}
