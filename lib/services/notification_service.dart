import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/player_stats.dart';

/// Local-only (no Firebase/push, v1 scope) reminders meant to bring a
/// player back: a Daily Challenge nudge, a streak-about-to-expire
/// warning, and an inactivity win-back. Static, matching the
/// `AuthService`/`StreakService` convention — this app needs exactly one
/// of these, not an instance per screen.
///
/// Every public method is best-effort: a missing platform channel (tests,
/// an unsupported platform, a denied permission) must never throw or
/// block anything else, same "best-effort, never load-bearing" precedent
/// `AdsService` already set for every ad SDK touch-point.
abstract final class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Fixed per-reminder IDs — scheduling with the same ID again (after an
  // explicit cancel, see _cancelAndMaybeSchedule below) is what makes
  // rescheduleAll's "cancel-then-reschedule, never additive" guarantee
  // work; without a fixed ID per reminder kind, repeated calls would pile
  // up duplicate scheduled notifications instead of replacing them.
  static const int _dailyChallengeId = 101;
  static const int _streakWarningId = 102;
  static const int _inactivityId = 103;

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';

  static bool _initialized = false;

  /// Sets up the plugin and requests the Android 13+ POST_NOTIFICATIONS
  /// runtime permission. Called once from `main()`, alongside
  /// `AdsService.initialize()`/`Supabase.initialize()`. Safe to call more
  /// than once (a no-op after the first successful run).
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      initializeTimeZones();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = true;
    } catch (_) {
      // A plugin/platform failure here must never block app startup.
    }
  }

  /// Whether [stats].lastDailyChallengeDate falls on the same UTC
  /// calendar day as [now] — the "done today" check behind
  /// [rescheduleAll]'s dailyChallengeDoneToday flag, exposed here so
  /// every caller shares one implementation instead of each re-deriving
  /// it. UTC (not local), matching every other day-boundary in this app
  /// (GameController's Daily Challenge seed, StreakService's streak day).
  static bool isDailyChallengeDoneToday(PlayerStats stats, DateTime now) {
    final date = stats.lastDailyChallengeDate;
    if (date == null) return false;
    final utcDate = date.toUtc();
    final utcNow = now.toUtc();
    return utcDate.year == utcNow.year &&
        utcDate.month == utcNow.month &&
        utcDate.day == utcNow.day;
  }

  /// When the Daily Challenge reminder should fire — null if it
  /// shouldn't be scheduled at all (already done today, or today's 18:00
  /// has already passed). A pure function (no plugin/platform touch), so
  /// this is independently unit-testable without a real notification
  /// plugin — see `_cancelAndMaybeSchedule` for where the result is
  /// actually handed to the plugin.
  static DateTime? dailyChallengeReminderTarget({
    required bool dailyChallengeDoneToday,
    required DateTime now,
  }) {
    if (dailyChallengeDoneToday) return null;
    final target = _todayAt(now, hour: 18);
    return target.isAfter(now) ? target : null;
  }

  /// When the streak-about-to-expire warning should fire — null if it
  /// shouldn't be scheduled (no active streak, already played today, or
  /// today's 20:00 has already passed).
  static DateTime? streakWarningTarget({
    required int currentStreakDays,
    required bool dailyChallengeDoneToday,
    required DateTime now,
  }) {
    if (currentStreakDays <= 0 || dailyChallengeDoneToday) return null;
    final target = _todayAt(now, hour: 20);
    return target.isAfter(now) ? target : null;
  }

  /// When the inactivity win-back should fire — always non-null (always
  /// rescheduled every call, per the feature plan): 3 days from
  /// [lastPlayedDate] (or [now], if the player has never played), clamped
  /// forward to at least 3 days from [now] if that would otherwise land
  /// in the past.
  static DateTime inactivityReminderTarget({
    required DateTime? lastPlayedDate,
    required DateTime now,
  }) {
    final basis = lastPlayedDate ?? now;
    final target = basis.add(const Duration(days: 3));
    return target.isAfter(now) ? target : now.add(const Duration(days: 3));
  }

  /// The single entry point for (re)computing every reminder from current
  /// player state — called from `home_screen.dart` (after stats load) and
  /// `game_screen.dart` (after every session ends). Always cancels each
  /// reminder's previous instance before deciding whether to reschedule
  /// it, so this is safe to call repeatedly without ever stacking
  /// duplicates.
  ///
  /// [now] defaults to the real current time; tests inject a fixed value
  /// for deterministic target-time assertions (though the three
  /// `*Target` methods above are what tests actually exercise directly —
  /// this method itself touches the real plugin and isn't unit-tested).
  static Future<void> rescheduleAll({
    required PlayerStats stats,
    required bool dailyChallengeDoneToday,
    DateTime? now,
  }) async {
    if (!_initialized) return; // never throws if initialize() didn't run
    now ??= DateTime.now();

    await _cancelAndMaybeSchedule(
      id: _dailyChallengeId,
      target: dailyChallengeReminderTarget(
        dailyChallengeDoneToday: dailyChallengeDoneToday,
        now: now,
      ),
      title: 'Today\'s Daily Challenge is waiting',
      body: 'Jump in and earn some bonus marks before the day ends!',
    );

    await _cancelAndMaybeSchedule(
      id: _streakWarningId,
      target: streakWarningTarget(
        currentStreakDays: stats.currentStreakDays,
        dailyChallengeDoneToday: dailyChallengeDoneToday,
        now: now,
      ),
      title: 'Don\'t lose your ${stats.currentStreakDays}-day streak 🔥',
      body: 'Play one quick round today to keep it going.',
    );

    await _cancelAndMaybeSchedule(
      id: _inactivityId,
      target: inactivityReminderTarget(
        lastPlayedDate: stats.lastPlayedDate,
        now: now,
      ),
      title: 'Your brain misses a workout 🧠',
      body: 'It\'s been a few days — come back for a quick round!',
    );
  }

  /// Cancels every pending reminder — called from `AuthService.
  /// deleteAccount()` (alongside `StorageService.clearAll()`) so a
  /// deleted account's device stops getting reminders tied to an
  /// identity that no longer exists. Deliberately never called on a
  /// plain sign-out.
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Best-effort — nothing downstream depends on this succeeding.
    }
  }

  /// [hour] o'clock today, in the device's own local time — computed from
  /// plain local [DateTime]s, then converted to a UTC instant right
  /// before scheduling (see _cancelAndMaybeSchedule), so this fires at
  /// the right real-world moment without needing the device's IANA
  /// timezone name (which `timezone` alone can't look up).
  static DateTime _todayAt(DateTime now, {required int hour}) {
    return DateTime(now.year, now.month, now.day, hour);
  }

  /// [target] null means "don't schedule this one" (the matching
  /// `*Target` method already decided that) — this always cancels any
  /// previous instance first regardless, so a reminder that's no longer
  /// due is actually removed, not just left un-replaced.
  static Future<void> _cancelAndMaybeSchedule({
    required int id,
    required DateTime? target,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.cancel(id: id);
      if (target == null) return;

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(target.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(_channelId, _channelName),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Best-effort — a scheduling failure must never crash the caller.
    }
  }
}
