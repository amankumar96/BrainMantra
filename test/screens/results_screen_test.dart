import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/game_session.dart';
import 'package:math_blitz/models/puzzle.dart';
import 'package:math_blitz/models/test_session.dart';
import 'package:math_blitz/screens/results_screen.dart';

Puzzle _puzzle(int seed) => Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.arithmetic,
      questionText: '$seed + $seed = ?',
      options: ['${seed * 2}', '99', '1', '2'],
      correctAnswer: seed * 2,
      difficultyTier: 1,
      timeLimitSeconds: 120,
    );

TestSession _buildSession(List<AnswerOutcome> outcomes, List<int> marks) {
  final puzzles = List.generate(outcomes.length, (i) => _puzzle(i + 1));
  final session = GameSession(
    startedAt: DateTime.utc(2026, 1, 1),
    score: marks.fold(0, (a, b) => a + b),
    comboMultiplier: 1,
    livesRemaining: 0,
    puzzlesAnswered: puzzles,
    correctness: outcomes.map((o) => o == AnswerOutcome.correct).toList(),
    isDailyChallenge: false,
  );
  return TestSession(session: session, outcomes: outcomes, marksAwarded: marks);
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets(
      'shows total marks and the correct/wrong/skipped breakdown',
      (tester) async {
    final testSession = _buildSession(
      [
        AnswerOutcome.correct,
        AnswerOutcome.correct,
        AnswerOutcome.wrong,
        AnswerOutcome.skipped,
      ],
      [4, 4, -2, 0],
    );
    await tester.pumpWidget(_wrap(ResultsScreen(
      testSession: testSession,
      previousHighScore: 100,
      onPlayAgain: () {},
    )));

    expect(find.text('6'), findsOneWidget); // total marks: 4+4-2+0
    expect(find.text('Correct: 2'), findsOneWidget);
    expect(find.text('Wrong: 1'), findsOneWidget);
    expect(find.text('Skipped: 1'), findsOneWidget);
  });

  testWidgets('shows the NEW HIGH SCORE banner when beaten', (tester) async {
    final testSession = _buildSession([AnswerOutcome.correct], [4]);
    await tester.pumpWidget(_wrap(ResultsScreen(
      testSession: testSession,
      previousHighScore: 0,
      onPlayAgain: () {},
    )));

    expect(find.text('NEW HIGH SCORE!'), findsOneWidget);
    expect(find.text('Best score: 4'), findsOneWidget);
  });

  testWidgets('hides the banner and keeps the old best when not beaten',
      (tester) async {
    final testSession = _buildSession([AnswerOutcome.wrong], [-2]);
    await tester.pumpWidget(_wrap(ResultsScreen(
      testSession: testSession,
      previousHighScore: 50,
      onPlayAgain: () {},
    )));

    expect(find.text('NEW HIGH SCORE!'), findsNothing);
    expect(find.text('Best score: 50'), findsOneWidget);
  });

  testWidgets('tapping Play Again calls onPlayAgain exactly once',
      (tester) async {
    var tapCount = 0;
    final testSession = _buildSession([AnswerOutcome.correct], [4]);
    await tester.pumpWidget(_wrap(ResultsScreen(
      testSession: testSession,
      previousHighScore: 0,
      onPlayAgain: () => tapCount++,
    )));

    await tester.tap(find.text('Play Again'));
    await tester.pump();

    expect(tapCount, equals(1));
  });
}
