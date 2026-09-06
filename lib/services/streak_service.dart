/// Computes the day-streak transition for `PlayerStats.currentStreakDays`.
/// Pure and stateless — no `shared_preferences`/`StorageService` dependency
/// — so it's fully unit-testable with injected dates, matching the house
/// pattern (`difficulty_curve.dart`, `rng_service.dart`).
abstract final class StreakService {
  /// The new `currentStreakDays` value for a session that just ended at
  /// [now], given the player's previous streak and their last-played date.
  ///
  /// - [lastPlayedDate] null (first-ever play) → 1.
  /// - Same UTC calendar day as [now] → unchanged (`previousStreakDays`);
  ///   playing a second session today doesn't double-count the day.
  /// - Exactly one UTC calendar day earlier → `previousStreakDays + 1`.
  /// - Any other gap — more than a day, or negative (defensive: clock
  ///   skew or a corrupted stored date should never crash or produce a
  ///   nonsensical streak, same philosophy as
  ///   `DifficultyCurve.randomTierForScore`'s negative-score handling) —
  ///   resets to 1.
  ///
  /// Comparisons use **UTC calendar days**, not local time — this
  /// deliberately matches `GameController`'s own UTC-day boundary for
  /// Daily Challenge's seed (`_todaySeedString`), so "today" means the
  /// same thing for streaks as it does for daily-challenge fairness.
  static int nextStreakDays({
    required int previousStreakDays,
    required DateTime? lastPlayedDate,
    required DateTime now,
  }) {
    if (lastPlayedDate == null) return 1;

    final today = _utcCalendarDay(now);
    final last = _utcCalendarDay(lastPlayedDate);
    final gapDays = today.difference(last).inDays;

    if (gapDays == 0) return previousStreakDays;
    if (gapDays == 1) return previousStreakDays + 1;
    return 1;
  }

  /// [dt] truncated to just its UTC calendar date (midnight UTC), so two
  /// [DateTime]s on the same UTC day diff to exactly 0 regardless of the
  /// time-of-day or local-timezone component either was captured in.
  static DateTime _utcCalendarDay(DateTime dt) {
    final utc = dt.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }
}
