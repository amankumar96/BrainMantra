import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/leaderboard_service.dart';

// LeaderboardService itself talks directly to the live Supabase project
// (submitDailyResult/fetchTopRankings) — there's no lightweight fake
// SupabaseClient to unit-test that against, so those two are verified
// manually against the real project instead (see ARCHITECTURE.md's Phase
// 2 amendment). LeaderboardEntry.fromRow is the one piece of pure parsing
// logic here, and is worth covering on its own.
void main() {
  test('fromRow parses a leaderboard_last_30_days row correctly', () {
    final entry = LeaderboardEntry.fromRow({
      'user_id': 'abc-123',
      'display_name': 'Aarav',
      'total_marks': 42,
      'tests_taken': 5,
      'last_active': '2026-09-05T10:00:00Z', // present in the row, unused
    });

    expect(entry.userId, equals('abc-123'));
    expect(entry.displayName, equals('Aarav'));
    expect(entry.totalMarks, equals(42));
    expect(entry.testsTaken, equals(5));
  });

  test('fromRow handles a negative total (more wrong than correct answers)',
      () {
    final entry = LeaderboardEntry.fromRow({
      'user_id': 'abc-456',
      'display_name': 'Priya',
      'total_marks': -6,
      'tests_taken': 3,
    });

    expect(entry.totalMarks, equals(-6));
  });
}
