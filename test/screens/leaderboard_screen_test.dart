import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/screens/leaderboard_screen.dart';
import 'package:brain_mantra/services/leaderboard_service.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _alice = LeaderboardEntry(
  userId: 'u-alice',
  displayName: 'Alice Kumar',
  totalScore: 320,
);
const _bob = LeaderboardEntry(
  userId: 'u-bob',
  displayName: 'Bob',
  totalScore: 210,
);
const _carol = LeaderboardEntry(
  userId: 'u-carol',
  displayName: 'Carol Singh',
  totalScore: 150,
);
const _dave = LeaderboardEntry(
  userId: 'u-dave',
  displayName: 'Dave',
  totalScore: 90,
);

void main() {
  // LeaderboardScreen itself talks to Supabase directly (fetchTopRankings,
  // fetchMyEntryAndRank, and `Supabase.instance.client.auth.currentUser`),
  // and Supabase is never initialized in a widget test (same constraint
  // delete_account_screen_test.dart already works around) — so the real
  // fetch always fails here. What *is* reachable without a mocked Supabase
  // client: the loading/error states below, and the header's own static
  // UI. The podium/list/row/avatar/your-position widgets are tested
  // separately, further down, by constructing them directly with fixture
  // LeaderboardEntry data — decoupled from the fetch entirely, so real
  // dynamic-data rendering is still genuinely exercised.
  group('LeaderboardScreen (network-dependent states)', () {
    testWidgets('shows a loading skeleton while the leaderboard loads', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));

      // Deliberately not settling — the fetch never resolves successfully
      // in this environment (no Supabase), so the skeleton is what the
      // very first frame shows.
      expect(
        find.byKey(const Key('leaderboard-loading-skeleton')),
        findsOneWidget,
      );
    });

    testWidgets(
      'surfaces a retry-able error rather than crashing when the fetch '
      'fails (Supabase is not initialized in this test)',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));
        await tester.pump(); // let the failed Future resolve

        expect(
          find.textContaining('Could not load the leaderboard'),
          findsOneWidget,
        );
        final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
        expect(retryButton, findsOneWidget);

        // Tapping Retry re-fetches (and fails again, same environment) —
        // just confirming this doesn't throw and the error state persists.
        await tester.tap(retryButton);
        await tester.pump();
        await tester.pump(); // let the re-triggered failed Future resolve
        expect(
          find.textContaining('Could not load the leaderboard'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows the "Leaderboard" title and "Last 30 Days" period', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));

      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Last 30 Days'), findsOneWidget);
    });

    testWidgets('the back arrow pops the route', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardScreen), findsNothing);
    });
  });

  group('LeaderboardPodium', () {
    testWidgets('renders each entry\'s real name, rank and marks dynamically', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LeaderboardPodium(topThree: [_alice, _bob, _carol])),
      );

      expect(find.text('Alice Kumar'), findsOneWidget);
      expect(find.text('320'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('Carol Singh'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      // Podium base labels — rank numbers, not hardcoded names.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders gracefully with fewer than 3 entries', (tester) async {
      await tester.pumpWidget(
        _wrap(const LeaderboardPodium(topThree: [_alice])),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Alice Kumar'), findsOneWidget);
    });

    testWidgets('renders nothing for an empty list', (tester) async {
      await tester.pumpWidget(_wrap(const LeaderboardPodium(topThree: [])));
      expect(tester.takeException(), isNull);
      expect(find.byType(LeaderboardAvatar), findsNothing);
    });
  });

  group('LeaderboardListSection / LeaderboardRow', () {
    testWidgets('renders every entry with its own dynamic rank/name/marks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LeaderboardListSection(entries: [_carol, _dave], startRank: 4),
        ),
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.text('Carol Singh'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('shows a "You" chip only on the current user\'s row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LeaderboardListSection(
            entries: [_carol, _dave],
            startRank: 4,
            currentUserId: 'u-dave',
          ),
        ),
      );

      expect(find.text('You'), findsOneWidget);
      // Dave's real name still renders — "You" never replaces it.
      expect(find.text('Dave'), findsOneWidget);
    });
  });

  group('YourPositionCard', () {
    testWidgets('shows the real rank, name, and marks passed to it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const YourPositionCard(rank: 47, entry: _dave)),
      );

      expect(find.text('47'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Your Position'), findsOneWidget);
    });
  });

  group('LeaderboardAvatar', () {
    testWidgets('falls back to generated initials when there is no avatarUrl', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LeaderboardAvatar(entry: _alice)));
      expect(find.text('AK'), findsOneWidget); // Alice Kumar
    });

    testWidgets('a single-word name yields a single initial', (tester) async {
      await tester.pumpWidget(_wrap(const LeaderboardAvatar(entry: _bob)));
      expect(find.text('B'), findsOneWidget);
    });
  });
}
