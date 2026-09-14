import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/screens/game_screen.dart';
import 'package:math_blitz/screens/home_screen.dart';
import 'package:math_blitz/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows 0/0 gracefully on a fresh install (no prior data)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('High Score: 0'), findsOneWidget);
    expect(find.text('Streak: 0 days'), findsOneWidget);
  });

  testWidgets('shows previously saved stats once loaded', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('High Score: 250'), findsOneWidget);
    expect(find.text('Streak: 3 days'), findsOneWidget);
  });

  testWidgets(
      'the rules dialog opens automatically on a fresh install and is '
      'not shown again on the next launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('How MathBlitz Works'), findsOneWidget);
    expect(await StorageService.hasSeenRules(), isFalse,
        reason: 'should only be marked seen once the dialog is dismissed');

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();

    expect(find.text('How MathBlitz Works'), findsNothing);
    expect(await StorageService.hasSeenRules(), isTrue);
  });

  testWidgets('tapping Play navigates to GameScreen', (tester) async {
    // Rules already seen — this test is about the Play button, not the
    // auto-shown dialog (which would otherwise sit on top and block the
    // tap below, same as a real returning player who already dismissed
    // it once).
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    // Deliberately not pumpAndSettle() here: GameScreen's TimerBar runs a
    // genuinely long (up to 30-minute) AnimationController that would
    // never "settle" within pumpAndSettle's frame-scheduling check — a
    // couple of plain pumps is enough to let the navigation complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('tapping the rules icon reopens the rules dialog on demand',
      (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('How MathBlitz Works'), findsNothing);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('How MathBlitz Works'), findsOneWidget);
  });

  testWidgets('the account menu offers Sign out and Delete account',
      (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets(
      'Delete account opens a confirmation dialog; Cancel dismisses it '
      'without deleting anything', (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // Two "Delete account"-flavored controls now coexist: the (dismissed
    // but not yet gone from the tree) menu item and the dialog's own
    // "Delete" button — searching for the dialog's exact button text
    // avoids ambiguity between them.
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
  });

  testWidgets(
      'confirming Delete surfaces an error (Supabase is not initialized '
      'in this test) rather than crashing or silently signing out',
      (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_rules': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not delete account'), findsOneWidget);
    // Still on Home - a failed delete must not navigate away or sign out.
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
