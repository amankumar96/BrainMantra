import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of the ranked leaderboard — a player's total marks across
/// Daily Challenges completed in the last 30 days.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int totalMarks;
  final int testsTaken;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalMarks,
    required this.testsTaken,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) => LeaderboardEntry(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String,
        totalMarks: row['total_marks'] as int,
        testsTaken: row['tests_taken'] as int,
      );
}

/// Wraps the two Supabase tables Part B added: submitting a Daily
/// Challenge result, and reading the ranked `leaderboard_last_30_days`
/// view (see ARCHITECTURE.md's Phase 2 amendment for the SQL that
/// defines it — "active in the last 30 days" simply means "has at least
/// one row in that window", which the view's join already guarantees).
abstract final class LeaderboardService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Records today's Daily Challenge result for the signed-in player.
  /// Upserts on (user_id, test_date) — replaying the same day's challenge
  /// overwrites that day's row rather than creating a duplicate, so the
  /// leaderboard always reflects each player's latest submission per day.
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

  /// The ranked leaderboard, highest marks first.
  static Future<List<LeaderboardEntry>> fetchTopRankings({int limit = 50}) async {
    final rows = await _client
        .from('leaderboard_last_30_days')
        .select()
        .order('total_marks', ascending: false)
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
