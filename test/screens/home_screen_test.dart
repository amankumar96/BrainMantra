import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/screens/delete_account_screen.dart';
import 'package:brain_mantra/screens/game_screen.dart';
import 'package:brain_mantra/screens/home_screen.dart';
import 'package:brain_mantra/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GameScreen's own `TimerBar` runs a genuinely long-running
/// `AnimationController`, so `pumpAndSettle()` after navigating there
/// would wait indefinitely and eventually time out — the same class of
/// problem `game_screen_test.dart`'s Play-button test already works
/// around. A couple of bounded manual pumps (enough for a dialog
/// fade-in or a route transition to complete) replaces every
/// `pumpAndSettle()` below.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('shows 0/0 gracefully on a fresh install (no prior data)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.textContaining('Hey '), findsOneWidget);
    expect(find.textContaining('Your day streak is 0'), findsOneWidget);
    // The marks badge — a standalone Text showing the real current score
    // fetched from the backend (defaults to 0 while that fetch is still
    // in flight — see home_screen.dart's _currentMarks doc).
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets(
    'shows the previously saved streak once loaded (the marks badge is '
    "backend-driven, not local — see its own field doc comment",
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'player_stats':
            '{"highScore":250,"currentStreakDays":3,"lastPlayedDate":null,'
            '"totalCoins":0,"bestScoreByTier":{}}',
        // Marking rules already-seen here so this test can focus purely on
        // stats loading — the auto-shown-once dialog has its own dedicated
        // test below.
        'has_seen_rules': true,
      });
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await _settle(tester);

      expect(find.textContaining('Your day streak is 3'), findsOneWidget);
      // NOT '250' — the marks badge deliberately ignores the locally-cached
      // PlayerStats.highScore (a "personal best, never decreases" value)
      // and instead fetches the real current score from the backend
      // (AuthService.fetchCurrentScore(), which — like every other Supabase
      // call in this test environment — fails and defensively returns 0).
      expect(find.text('0'), findsOneWidget);
    },
  );

  testWidgets('the rules dialog opens automatically on a fresh install and is '
      'not shown again on the next launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.text('How Brain Mantra Works'), findsOneWidget);
    expect(
      await StorageService.hasSeenRules(),
      isFalse,
      reason: 'should only be marked seen once the dialog is dismissed',
    );

    await tester.tap(find.text('I understand'));
    await _settle(tester);

    expect(find.text('How Brain Mantra Works'), findsNothing);
    expect(await StorageService.hasSeenRules(), isTrue);
  });

  testWidgets('tapping Play navigates to GameScreen', (tester) async {
    // Rules already seen — this test is about the Play button, not the
    // auto-shown dialog (which would otherwise sit on top and block the
    // tap below, same as a real returning player who already dismissed
    // it once).
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.text('PLAY'));
    // GameScreen's own TimerBar runs a genuinely long (up to 30-minute)
    // AnimationController on top of Home's now-also-infinite background —
    // a couple of plain pumps is enough to let the navigation complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('tapping the rules icon reopens the rules dialog on demand', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    expect(find.text('How Brain Mantra Works'), findsNothing);

    await tester.tap(find.byIcon(Icons.info_outline));
    await _settle(tester);

    expect(find.text('How Brain Mantra Works'), findsOneWidget);
  });

  testWidgets('the Delete Account button navigates to DeleteAccountScreen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.text('Delete Account'), findsOneWidget);
    // Now a normal full-width flow item at the bottom of a scrollable
    // Column (no longer a corner-pinned Positioned button) — scroll it
    // into view first, same as any tall content on a real phone screen.
    await tester.ensureVisible(find.text('Delete Account'));
    await tester.pump();
    await tester.tap(find.text('Delete Account'));
    await _settle(tester);

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });

  testWidgets('the Sign out icon is still a direct, one-tap action', (
    tester,
  ) async {
    // Not exercising what it actually does (that's Supabase-bound, same
    // as elsewhere in this codebase) - just confirming it's still a
    // plain, always-visible icon rather than tucked behind a menu.
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byIcon(Icons.logout), findsOneWidget);
  });
}
