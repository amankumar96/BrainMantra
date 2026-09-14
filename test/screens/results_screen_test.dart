import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/game_session.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/models/test_session.dart';
import 'package:brain_mantra/screens/results_screen.dart';

Puzzle _puzzle(int seed) => Puzzle(
      category: PuzzleCategory.mathTest,
      type: PuzzleType.arithmetic,
      questionText: '$seed + $seed = ?',
      options: ['${seed * 2}', '99', '1', '2'],
      correctAnswer: seed * 2,
      difficultyTier: 1,
      timeLimitSeconds: 120,
    );

/// [cumulativeScore] defaults to matching the session's own delta sum
/// (`session.score`) — the normal Daily Challenge case, where startingScore
/// is always 0 so "this session's total" and "the cumulative score" are
/// the same number. Pass it explicitly to simulate Play mode, where they
/// legitimately differ.
TestSession _buildSession(
  List<AnswerOutcome> outcomes,
  List<int> marks, {
  bool isDailyChallenge = true,
  int? cumulativeScore,
}) {
  final puzzles = List.generate(outcomes.length, (i) => _puzzle(i + 1));
  final sessionDelta = marks.fold(0, (a, b) => a + b);
  final session = GameSession(
    startedAt: DateTime.utc(2026, 1, 1),
    score: cumulativeScore ?? sessionDelta,
    comboMultiplier: 1,
    livesRemaining: 0,
    puzzlesAnswered: puzzles,
    correctness: outcomes.map((o) => o == AnswerOutcome.correct).toList(),
    isDailyChallenge: isDailyChallenge,
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
      currentScore: testSession.session.score,
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
      currentScore: testSession.session.score,
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
      currentScore: testSession.session.score,
      previousHighScore: 50,
      onPlayAgain: () {},
    )));

    expect(find.text('NEW HIGH SCORE!'), findsNothing);
    expect(find.text('Best score: 50'), findsOneWidget);
  });

  testWidgets('Daily Challenge: tapping "Play Again" calls onPlayAgain',
      (tester) async {
    var tapCount = 0;
    final testSession = _buildSession([AnswerOutcome.correct], [4]);
    await tester.pumpWidget(_wrap(ResultsScreen(
      testSession: testSession,
      currentScore: testSession.session.score,
      previousHighScore: 0,
      onPlayAgain: () => tapCount++,
    )));

    expect(find.text('Test Complete'), findsOneWidget);
    await tester.tap(find.text('Play Again'));
    await tester.pump();

    expect(tapCount, equals(1));
  });

  group('Play mode (currentScore is the cumulative total, not the '
      "session's own delta)", () {
    testWidgets(
        'shows currentScore as the headline number, not '
        "testSession's session-local delta", (tester) async {
      // This session only earned +4, but the player's persisted running
      // total (currentScore) is 104 — the screen must show 104, the real
      // "score till now", not 4.
      final testSession = _buildSession(
        [AnswerOutcome.correct],
        [4],
        isDailyChallenge: false,
        cumulativeScore: 104,
      );
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 104,
        previousHighScore: 100,
        onPlayAgain: () {},
      )));

      expect(find.text('104'), findsOneWidget);
      expect(find.text('4'), findsNothing);
      expect(find.text('score so far'), findsOneWidget);
      expect(find.text('Session Ended'), findsOneWidget);
    });

    testWidgets('shows "Continue Playing" instead of "Play Again"',
        (tester) async {
      final testSession = _buildSession(
        [AnswerOutcome.correct],
        [4],
        isDailyChallenge: false,
        cumulativeScore: 104,
      );
      var tapCount = 0;
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 104,
        previousHighScore: 100,
        onPlayAgain: () => tapCount++,
      )));

      expect(find.text('Play Again'), findsNothing);
      await tester.tap(find.text('Continue Playing'));
      await tester.pump();

      expect(tapCount, equals(1));
    });
  });
}
