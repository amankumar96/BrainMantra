import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/leaderboard_service.dart';

// LeaderboardService itself talks directly to the live Supabase project
// (submitDailyResult/fetchTopRankings) — there's no lightweight fake
// SupabaseClient to unit-test that against, so those two are verified
// manually against the real project instead (see ARCHITECTURE.md's Phase
// 2 amendment). LeaderboardEntry.fromRow is the one piece of pure parsing
// logic here, and is worth covering on its own.
void main() {
  test('fromRow parses a profiles row correctly', () {
    final entry = LeaderboardEntry.fromRow({
      'id': 'abc-123',
      'display_name': 'Aarav',
      'current_score': 140,
    });

    expect(entry.userId, equals('abc-123'));
    expect(entry.displayName, equals('Aarav'));
    expect(entry.totalScore, equals(140));
    // avatar_url isn't currently queried — see LeaderboardEntry.avatarUrl's
    // own doc comment — so a row without that key must parse to null,
    // never throw.
    expect(entry.avatarUrl, isNull);
  });

  test('fromRow reads avatar_url when the row happens to include it', () {
    final entry = LeaderboardEntry.fromRow({
      'id': 'abc-789',
      'display_name': 'Meera',
      'current_score': 60,
      'avatar_url': 'https://example.com/a.png',
    });

    expect(entry.avatarUrl, equals('https://example.com/a.png'));
  });

  test(
    'fromRow handles a negative total (more wrong than correct answers)',
    () {
      final entry = LeaderboardEntry.fromRow({
        'id': 'abc-456',
        'display_name': 'Priya',
        'current_score': -6,
      });

      expect(entry.totalScore, equals(-6));
    },
  );
}
