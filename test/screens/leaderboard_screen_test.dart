import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/screens/leaderboard_screen.dart';

/// LeaderboardScreen talks to Supabase directly (fetchTopRankings,
/// fetchMyEntryAndRank, and `Supabase.instance.client.auth.currentUser`),
/// and Supabase is never initialized in a widget test (same constraint
/// delete_account_screen_test.dart already works around) — so the real
/// rank-card/top-10 rendering can't be exercised here without a mocked
/// Supabase client, which this codebase doesn't have. What *is*
/// reachable without one: the loading state, and the error state that
/// results from every Supabase call failing outright — both verified
/// below.
void main() {
  testWidgets('shows a loading indicator while the leaderboard loads',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));

    // Deliberately not settling — the fetch never resolves successfully
    // in this environment (no Supabase), so the loading spinner is what
    // the very first frame shows.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'surfaces an error rather than crashing when the fetch fails '
      '(Supabase is not initialized in this test)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));
    await tester.pump(); // let the failed Future resolve

    expect(find.textContaining('Could not load the leaderboard'),
        findsOneWidget);
  });

  testWidgets('shows the "Leaderboard — Last 30 Days" title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));

    expect(find.text('Leaderboard — Last 30 Days'), findsOneWidget);
  });
}
