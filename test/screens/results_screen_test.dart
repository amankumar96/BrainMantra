import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brain_mantra/models/age_group.dart';
import 'package:brain_mantra/models/app_language.dart';
import 'package:brain_mantra/models/game_session.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/models/test_session.dart';
import 'package:brain_mantra/screens/results_screen.dart';
import 'package:brain_mantra/services/language_controller.dart';

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

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageController>(
      create: (_) => LanguageController(AppLanguage.english),
      child: MaterialApp(home: child),
    );

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

  group('Age-Group Test mode (ageGroupTest set)', () {
    /// [correctCount] correct answers followed by (30 - correctCount)
    /// wrong answers, out of a fixed 30 — matches the real 30-question
    /// Age-Group Test shape.
    TestSession buildAgeGroupSession(int correctCount) {
      final outcomes = [
        for (var i = 0; i < 30; i++)
          i < correctCount ? AnswerOutcome.correct : AnswerOutcome.wrong,
      ];
      final marks = [
        for (final o in outcomes) o == AnswerOutcome.correct ? 4 : -2,
      ];
      return _buildSession(outcomes, marks, isDailyChallenge: false);
    }

    testWidgets('shows no score, no high-score banner, no Best score line',
        (tester) async {
      final testSession = buildAgeGroupSession(15);
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 999, // must be ignored entirely in this mode
        previousHighScore: 0,
        ageGroupTest: AgeGroup.thirteenPlus,
        onPlayAgain: () {},
      )));

      expect(find.text('999'), findsNothing);
      expect(find.text('score so far'), findsNothing);
      expect(find.textContaining('Best score'), findsNothing);
      expect(find.text('NEW HIGH SCORE!'), findsNothing);
    });

    testWidgets('12/30 correct (exactly 40%) shows Congratulations',
        (tester) async {
      final testSession = buildAgeGroupSession(12);
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 0,
        previousHighScore: 0,
        ageGroupTest: AgeGroup.sixteenPlus,
        onPlayAgain: () {},
      )));

      expect(find.text('Congratulations! You passed'), findsOneWidget);
    });

    testWidgets('11/30 correct (just under 40%) shows Try again next time',
        (tester) async {
      final testSession = buildAgeGroupSession(11);
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 0,
        previousHighScore: 0,
        ageGroupTest: AgeGroup.eighteenPlus,
        onPlayAgain: () {},
      )));

      expect(find.text('Try again next time'), findsOneWidget);
    });

    testWidgets('title shows the age group label, and only a Back to Home '
        'button is offered (no Try Again/Play Again bypassing the '
        'cooldown)', (tester) async {
      final testSession = buildAgeGroupSession(20);
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 0,
        previousHighScore: 0,
        ageGroupTest: AgeGroup.thirteenPlus,
        onPlayAgain: () {},
      )));

      expect(find.text('13+ Test Result'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.text('Play Again'), findsNothing);
      expect(find.text('Continue Playing'), findsNothing);
      expect(find.text('Try Again'), findsNothing);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('still shows the correct/wrong breakdown', (tester) async {
      final testSession = buildAgeGroupSession(18);
      await tester.pumpWidget(_wrap(ResultsScreen(
        testSession: testSession,
        currentScore: 0,
        previousHighScore: 0,
        ageGroupTest: AgeGroup.sixteenPlus,
        onPlayAgain: () {},
      )));

      expect(find.text('Correct: 18'), findsOneWidget);
      expect(find.text('Wrong: 12'), findsOneWidget);
      expect(find.text('Skipped: 0'), findsOneWidget);
    });
  });
}
