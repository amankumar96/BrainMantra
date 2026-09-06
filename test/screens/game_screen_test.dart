import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/controllers/game_controller.dart';
import 'package:math_blitz/models/puzzle.dart';
import 'package:math_blitz/screens/game_screen.dart';
import 'package:math_blitz/screens/results_screen.dart';
import 'package:math_blitz/services/rng_service.dart';
import 'package:math_blitz/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

/// The on-screen option label matching [puzzle]'s correct answer.
/// Deliberately NOT `puzzle.correctAnswer.toString()` directly — for
/// trueFalse puzzles the displayed options are "True"/"False" while
/// `bool.toString()` gives lowercase "true"/"false"; comparing
/// case-insensitively against the real options list (the same way
/// GameController itself checks correctness) is what actually finds the
/// button the player would tap.
String _correctLabel(Puzzle puzzle) {
  final correctText = puzzle.correctAnswer.toString().toLowerCase();
  return puzzle.options.firstWhere((o) => o.toLowerCase() == correctText);
}

/// Pumps in small steps rather than one big jump — see timer_bar_test.dart
/// for why (an AnimationController's ticker only establishes its
/// elapsed-time baseline once the pump machinery delivers a first real
/// frame, so a single large jump can land short of firing "completed").
Future<void> _pumpMillis(WidgetTester tester, int totalMillis,
    {int step = 100}) async {
  for (var elapsed = 0; elapsed < totalMillis; elapsed += step) {
    await tester.pump(Duration(milliseconds: step));
  }
}

void main() {
  // GameScreen persists via StorageService (shared_preferences) at the
  // end of a test — route it to the mock in-memory backend.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the question text and one button per option',
      (tester) async {
    final controller = GameController(
      totalQuestions: 3,
      isDailyChallenge: false,
      rng: RngService.seeded('gs-1'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    expect(find.text(controller.currentPuzzle!.questionText), findsOneWidget);
    for (final option in controller.currentPuzzle!.options) {
      expect(find.text(option), findsOneWidget);
    }
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets(
      'tapping a correct answer then Submit raises the marks total',
      (tester) async {
    final controller = GameController(
      totalQuestions: 3,
      isDailyChallenge: false,
      rng: RngService.seeded('gs-2'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    final correctLabel = _correctLabel(controller.currentPuzzle!);
    await tester.tap(find.text(correctLabel));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('+4 marks'), findsOneWidget);
  });

  testWidgets(
      'tapping a wrong answer then Submit lowers the marks total',
      (tester) async {
    final controller = GameController(
      totalQuestions: 3,
      isDailyChallenge: false,
      rng: RngService.seeded('gs-4'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    final puzzle = controller.currentPuzzle!;
    final correctLabel = _correctLabel(puzzle);
    final wrongAnswer = puzzle.options.firstWhere((o) => o != correctLabel);
    await tester.tap(find.text(wrongAnswer));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('-2 marks'), findsOneWidget);
  });

  testWidgets('completing every question navigates to ResultsScreen',
      (tester) async {
    final controller = GameController(
      totalQuestions: 2,
      isDailyChallenge: false,
      rng: RngService.seeded('gs-3'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    for (var i = 0; i < 2; i++) {
      final answer = _correctLabel(controller.currentPuzzle!);
      await tester.tap(find.text(answer));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      // Let the feedback animation finish so it auto-advances (or, on
      // the last question, triggers the post-frame navigation).
      await _pumpMillis(
        tester,
        AppDurations.feedbackDuration.inMilliseconds + 200,
      );
    }
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
  });

  testWidgets('an infinite (Play) session shows an End button that ends '
      'the session and navigates to ResultsScreen', (tester) async {
    final controller = GameController(
      totalQuestions: null, // Play mode — no cap
      isDailyChallenge: false,
      startingScore: 40,
      rng: RngService.seeded('gs-5'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    // Answer one question first, just to prove End works mid-session, not
    // only on the very first question.
    final answer = _correctLabel(controller.currentPuzzle!);
    await tester.tap(find.text(answer));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await _pumpMillis(tester, AppDurations.feedbackDuration.inMilliseconds + 200);

    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.text('End'), findsOneWidget);

    await tester.tap(find.text('End'));
    // Unlike the mid-question pumps above, pumpAndSettle is safe here:
    // endSession() makes the screen render a plain loading spinner (see
    // game_screen.dart's isSessionOver build-guard), tearing down the
    // long-running TimerBar that would otherwise never let this settle.
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
  });

  testWidgets('Daily Challenge does not show an End button', (tester) async {
    final controller = GameController(
      totalQuestions: 3,
      isDailyChallenge: true,
      rng: RngService.seeded('gs-6'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    expect(find.text('End'), findsNothing);
  });
}
