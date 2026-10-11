import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/player_stats.dart';

/// One slot in the unconditional "≥5/day" recurring baseline (see
/// [NotificationService.rescheduleAll]'s doc comment) — a fixed id,
/// time-of-day, and copy. Scheduled with `matchDateTimeComponents:
/// DateTimeComponents.time`, so the OS itself re-fires it every day at
/// that time, with no app code involved after the first successful
/// schedule call — unlike the three condition-aware reminders below,
/// these can't check live player state at delivery time, so they're
/// deliberately generic/unconditional by design.
class _RecurringSlot {
  const _RecurringSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
  });

  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
}

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

  // The unconditional, OS-recurring "≥5/day" baseline — guarantees a
  // delivery floor regardless of whether the player ever reopens the app
  // (see rescheduleAll's doc comment for why this exists alongside, not
  // instead of, the three conditional reminders above).
  static const int _morningId = 201;
  static const int _challengeUnlockId = 202;
  static const int _mathFactId = 203;
  static const int _streakReminderId = 204;
  static const int _eveningId = 205;

  // The 4 fixed-copy recurring slots — the math-fact slot (203) isn't
  // here since its body changes per day (see mathFactForDay); it's
  // scheduled separately in _scheduleRecurringBaseline.
  static const List<_RecurringSlot> _recurringSlots = [
    _RecurringSlot(
      id: _morningId,
      hour: 9,
      minute: 0,
      title: 'Good morning! 🌅',
      body: 'Start your day with a quick brain warm-up.',
    ),
    _RecurringSlot(
      id: _challengeUnlockId,
      hour: 10,
      minute: 30,
      title: "Today's Daily Challenge is live",
      body: 'Fresh puzzle just unlocked for today — go claim it.',
    ),
    _RecurringSlot(
      id: _streakReminderId,
      hour: 16,
      minute: 30,
      title: 'Keep your streak alive 🔥',
      body: "Just one quick round keeps today's habit going.",
    ),
    _RecurringSlot(
      id: _eveningId,
      hour: 21,
      minute: 30,
      title: 'One more round before bed? 🌙',
      body: 'A quick game before you wrap up the day.',
    ),
  ];

  // Short, self-contained math-history facts for the recurring "Math
  // Fact of the Day" slot — kept as a small inline list (no asset file,
  // no network fetch, no extra stored state) rather than a bigger
  // content system, since this is meant to stay a light touch, not a
  // standalone feature.
  static const List<String> _mathFacts = [
    'Pythagoras led a secret society that banned eating beans.',
    'Euler kept producing major math work after going completely blind.',
    "Zero as a number wasn't widely used in Europe until the 1200s.",
    'The "=" sign was invented because its creator was tired of writing '
        '"is equal to" by hand.',
    'Ramanujan taught himself advanced mathematics from a single old '
        'textbook.',
    "Fibonacci's famous sequence first appeared in a problem about "
        'rabbit breeding.',
    'Archimedes reportedly ran through the streets shouting "Eureka!" '
        'after a bathtub discovery.',
    'As a schoolboy, Gauss summed 1 to 100 in seconds by pairing up '
        'numbers.',
    'The word "algebra" comes from Arabic "al-jabr", meaning "reunion of '
        'broken parts".',
    'Newton and Leibniz each invented calculus independently, sparking a '
        'bitter rivalry.',
    'Ada Lovelace wrote the first published computer algorithm — in the '
        '1840s.',
    "Pi has trillions of calculated digits, but about 39 are enough for "
        "any real-world measurement.",
    'The Babylonians used a base-60 number system — why an hour has 60 '
        'minutes.',
    'Alan Turing helped crack wartime codes and laid the groundwork for '
        'computer science.',
    'A "googol" (1 followed by 100 zeros) got its name from a '
        "mathematician's 9-year-old nephew.",
  ];

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

  /// A deterministic "fact of the day" pick — same calendar date always
  /// picks the same entry, with no stored index/state needed. Two
  /// different years landing on the same fact (day-of-year wraps past
  /// [_mathFacts]'s length) is an acceptable, harmless coincidence given
  /// how small this feature is meant to stay.
  static String mathFactForDay(DateTime now) {
    final startOfYear = DateTime(now.year);
    final dayOfYear = now.difference(startOfYear).inDays;
    return _mathFacts[dayOfYear % _mathFacts.length];
  }

  /// The next moment [hour]:[minute] (device-local) occurs at or after
  /// [now] — today if that time hasn't passed yet, otherwise tomorrow.
  /// This only decides the *first* fire time handed to `zonedSchedule`
  /// for a recurring slot; every fire after that is the OS repeating via
  /// `matchDateTimeComponents`, not this function being called again.
  static DateTime nextRecurringOccurrence(
    DateTime now, {
    required int hour,
    required int minute,
  }) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
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
  ///
  /// Two layers, kept deliberately separate:
  /// - The 3 reminders below (_refreshConditionalReminders) are
  ///   condition-aware one-shots-for-today, only ever (re-)armed while
  ///   the app is actually running — fine as a *bonus* layer, but on
  ///   their own they go silent for a player who stops opening the app,
  ///   exactly the player re-engagement notifications matter most for.
  /// - _scheduleRecurringBaseline guarantees a real, OS-level "≥5/day"
  ///   delivery floor that keeps firing daily forever once scheduled,
  ///   independent of whether the app is ever reopened again.
  static Future<void> rescheduleAll({
    required PlayerStats stats,
    required bool dailyChallengeDoneToday,
    DateTime? now,
  }) async {
    if (!_initialized) return; // never throws if initialize() didn't run
    now ??= DateTime.now();

    await _refreshConditionalReminders(
      stats: stats,
      dailyChallengeDoneToday: dailyChallengeDoneToday,
      now: now,
    );
    await _scheduleRecurringBaseline(now: now);
  }

  /// The existing 3 condition-aware, one-shot-per-day reminders.
  static Future<void> _refreshConditionalReminders({
    required PlayerStats stats,
    required bool dailyChallengeDoneToday,
    required DateTime now,
  }) async {
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

  /// Ensures all 5 recurring baseline slots are scheduled. The 4
  /// fixed-copy slots in [_recurringSlots] are only (re-)scheduled if
  /// not already pending — idempotent, so a player who opens the app
  /// daily doesn't pay a redundant reschedule for all 5 ids on every
  /// single launch. The math-fact slot is the one exception: it's always
  /// re-scheduled with today's fact, since a recurring notification's
  /// content is fixed at schedule time (the OS can't re-run
  /// [mathFactForDay] when it actually fires) — this means a player who
  /// never reopens the app keeps getting *a* fact reliably, just not
  /// necessarily that exact day's fact, which is an acceptable trade for
  /// keeping this feature this small.
  static Future<void> _scheduleRecurringBaseline({required DateTime now}) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final pendingIds = pending.map((r) => r.id).toSet();

      for (final slot in _recurringSlots) {
        if (pendingIds.contains(slot.id)) continue;
        await _scheduleRecurring(
          id: slot.id,
          hour: slot.hour,
          minute: slot.minute,
          title: slot.title,
          body: slot.body,
          now: now,
        );
      }

      await _scheduleRecurring(
        id: _mathFactId,
        hour: 13,
        minute: 0,
        title: 'Math Fact of the Day 📐',
        body: mathFactForDay(now),
        now: now,
      );
    } catch (_) {
      // Best-effort — same precedent as every other plugin touch here.
    }
  }

  /// Schedules one id to recur daily at [hour]:[minute] (device-local),
  /// via `matchDateTimeComponents: DateTimeComponents.time` — the OS
  /// itself re-fires it every day after this one call, with no further
  /// app involvement needed.
  static Future<void> _scheduleRecurring({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required DateTime now,
  }) async {
    await _plugin.cancel(id: id);
    final first = nextRecurringOccurrence(now, hour: hour, minute: minute);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(first.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
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
