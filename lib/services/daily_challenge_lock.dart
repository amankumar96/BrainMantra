/// Enforces the 24-hour lock on Daily Challenge: once played, the card
/// stays locked until a full day has passed. Pure and stateless — no
/// `StorageService` dependency — so it's fully unit-testable with
/// injected dates, matching the house pattern (`streak_service.dart`,
/// `difficulty_curve.dart`).
///
/// Deliberately distinct from the Age-Group Tests, which by explicit
/// product decision have no cooldown of any kind (see
/// `home_screen.dart`'s `_navigateToAgeGroupTest`) — Daily Challenge's
/// lock is a real, intentional restriction, not the same mechanism.
abstract final class DailyChallengeLock {
  static const Duration duration = Duration(hours: 24);

  /// Whether Daily Challenge is currently locked, given when it was last
  /// played (null = never played → never locked).
  static bool isLocked({
    required DateTime? lastPlayedDate,
    required DateTime now,
  }) {
    if (lastPlayedDate == null) return false;
    return now.difference(lastPlayedDate) < duration;
  }

  /// How much longer the lock has left — [Duration.zero] if it's already
  /// unlocked (or was never played). Never negative.
  static Duration remaining({
    required DateTime? lastPlayedDate,
    required DateTime now,
  }) {
    if (lastPlayedDate == null) return Duration.zero;
    final elapsed = now.difference(lastPlayedDate);
    if (elapsed >= duration) return Duration.zero;
    return duration - elapsed;
  }
}
