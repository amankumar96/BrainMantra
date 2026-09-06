import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/screens/game_screen.dart';
import 'package:math_blitz/screens/home_screen.dart';
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
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('High Score: 250'), findsOneWidget);
    expect(find.text('Streak: 3 days'), findsOneWidget);
  });

  testWidgets('tapping Play navigates to GameScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('tapping the rules icon opens the rules dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('How MathBlitz Works'), findsOneWidget);
  });
}
