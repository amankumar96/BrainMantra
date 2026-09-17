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

  /// Not currently queried by [LeaderboardService] — the `profiles` table
  /// isn't confirmed to have an `avatar_url` column, and adding it to a
  /// `select()` list against a column that doesn't exist would make
  /// every leaderboard fetch fail outright, so it's read defensively
  /// (present only if the row happens to include it) rather than
  /// requested. Always `null` today; the UI already falls back to a
  /// generated initials avatar wherever this is null, so a real column
  /// can be wired in later purely by adding it to the two `select()`
  /// calls in this file — no UI change needed.
  final String? avatarUrl;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalScore,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) =>
      LeaderboardEntry(
        userId: row['id'] as String,
        displayName: row['display_name'] as String,
        totalScore: row['current_score'] as int,
        avatarUrl: row['avatar_url'] as String?,
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

    await _client.from('daily_test_results').upsert({
      'user_id': user.id,
      'test_date': _todayDateString(),
      'marks': marks,
      'questions_total': questionsTotal,
    }, onConflict: 'user_id,test_date');
  }

  /// The ranked leaderboard: every player's persistent total score
  /// (`profiles.current_score`, Play + Daily Challenge combined), highest
  /// first, restricted to players active in the last 30 days
  /// (`profiles.last_active_at` — the same field the 30-day inactive-
  /// account deletion job checks). Queries `profiles` directly rather
  /// than the now-superseded `leaderboard_last_30_days` view, which only
  /// ever summed Daily Challenge marks.
  static Future<List<LeaderboardEntry>> fetchTopRankings({
    int limit = 50,
  }) async {
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

  /// The signed-in player's own leaderboard row plus their exact global
  /// rank (1-based) among players active in the last 30 days — computed
  /// as a count, not by scanning [fetchTopRankings]' capped list, so it's
  /// accurate even for a player far outside the top 50. `null` if nobody
  /// is signed in. Same RLS posture as [fetchTopRankings]: that call
  /// already reads `current_score` across every profile, not just the
  /// caller's own row, so a `count()` aggregate needs no new policy.
  static Future<({LeaderboardEntry entry, int rank})?>
  fetchMyEntryAndRank() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final profileRow = await _client
        .from('profiles')
        .select('id, display_name, current_score')
        .eq('id', user.id)
        .single();
    final entry = LeaderboardEntry.fromRow(profileRow);

    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final countResponse = await _client
        .from('profiles')
        .select('id')
        .gt('current_score', entry.totalScore)
        .gte('last_active_at', cutoff.toIso8601String())
        .count(CountOption.exact);

    return (entry: entry, rank: countResponse.count + 1);
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
