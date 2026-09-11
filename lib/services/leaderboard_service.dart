import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of the ranked leaderboard — a player's persistent total score
/// (Play + Daily Challenge combined; see ARCHITECTURE.md's Daily Challenge
/// redesign, which folds Daily Challenge's earned marks into the same
/// `profiles.current_score` Play resumes from — there's no separate
/// "Daily Challenge only" total anymore).
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int totalScore;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalScore,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) => LeaderboardEntry(
        userId: row['id'] as String,
        displayName: row['display_name'] as String,
        totalScore: row['current_score'] as int,
      );
}

/// Wraps the two Supabase tables Part B added: submitting a Daily
/// Challenge result (still recorded for history/audit even though the
/// leaderboard itself no longer ranks by it — see [fetchTopRankings]),
/// and reading the ranked leaderboard.
abstract final class LeaderboardService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Records today's Daily Challenge result for the signed-in player.
  /// Upserts on (user_id, test_date) — replaying the same day's challenge
  /// overwrites that day's row rather than creating a duplicate.
  static Future<void> submitDailyResult({
    required int marks,
    required int questionsTotal,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return; // defensive — the app requires sign-in first

    await _client.from('daily_test_results').upsert(
      {
        'user_id': user.id,
        'test_date': _todayDateString(),
        'marks': marks,
        'questions_total': questionsTotal,
      },
      onConflict: 'user_id,test_date',
    );
  }

  /// The ranked leaderboard: every player's persistent total score
  /// (`profiles.current_score`, Play + Daily Challenge combined), highest
  /// first, restricted to players active in the last 30 days
  /// (`profiles.last_active_at` — the same field the 30-day inactive-
  /// account deletion job checks). Queries `profiles` directly rather
  /// than the now-superseded `leaderboard_last_30_days` view, which only
  /// ever summed Daily Challenge marks.
  static Future<List<LeaderboardEntry>> fetchTopRankings({int limit = 50}) async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final rows = await _client
        .from('profiles')
        .select('id, display_name, current_score')
        .gte('last_active_at', cutoff.toIso8601String())
        .order('current_score', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => LeaderboardEntry.fromRow(row as Map<String, dynamic>))
        .toList();
  }
}

/// Today's date as `yyyy-MM-dd` (UTC) — matches the format Postgres
/// expects for a `date` column, and the same convention
/// `game_controller.dart` uses to seed a Daily Challenge's questions, so
/// "today" means the same day on both sides.
String _todayDateString() {
  final now = DateTime.now().toUtc();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
