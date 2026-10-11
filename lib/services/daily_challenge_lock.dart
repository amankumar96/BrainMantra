/// Enforces Daily Challenge's lock: once played, it's locked until the
/// next **10 AM local time** reset — not a flat 24-hour countdown from
/// the moment it was played. Pure and stateless — no `StorageService`
/// dependency — so it's fully unit-testable with injected dates,
/// matching the house pattern (`streak_service.dart`,
/// `difficulty_curve.dart`).
///
/// Deliberately distinct from the Age-Group Tests, which by explicit
/// product decision have no cooldown of any kind (see
/// `home_screen.dart`'s `_navigateToAgeGroupTest`) — Daily Challenge's
/// lock is a real, intentional restriction, not the same mechanism.
abstract final class DailyChallengeLock {
  /// The hour (local time, 24-hour clock) Daily Challenge resets at
  /// every day — TUNABLE.
  static const int resetHour = 10;

  /// The most recent reset boundary at or before [now] — e.g. if it's
  /// currently 2 PM, that's today's 10 AM; if it's currently 3 AM
  /// (before today's reset has happened yet), that's *yesterday's*
  /// 10 AM. [now] and the return value are both local time.
  static DateTime _mostRecentReset(DateTime now) {
    final local = now.toLocal();
    final todayReset =
        DateTime(local.year, local.month, local.day, resetHour);
    return local.isBefore(todayReset)
        ? todayReset.subtract(const Duration(days: 1))
        : todayReset;
  }

  /// Whether Daily Challenge is currently locked, given when it was
  /// last played (null = never played → never locked). Locked exactly
  /// when [lastPlayedDate] falls on or after the most recent reset
  /// boundary — i.e. "already played since the last reset."
  static bool isLocked({
    required DateTime? lastPlayedDate,
    required DateTime now,
  }) {
    if (lastPlayedDate == null) return false;
    return !lastPlayedDate.toLocal().isBefore(_mostRecentReset(now));
  }

  /// How much longer until the *next* reset — [Duration.zero] if it's
  /// already unlocked (or was never played). Never negative.
  static Duration remaining({
    required DateTime? lastPlayedDate,
    required DateTime now,
  }) {
    if (!isLocked(lastPlayedDate: lastPlayedDate, now: now)) {
      return Duration.zero;
    }
    final nextReset = _mostRecentReset(now).add(const Duration(days: 1));
    return nextReset.difference(now.toLocal());
  }
}
