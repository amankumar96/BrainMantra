import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/controllers/game_controller.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/models/test_session.dart';
import 'package:brain_mantra/screens/game_screen.dart';
import 'package:brain_mantra/screens/results_screen.dart';
import 'package:brain_mantra/services/rng_service.dart';
import 'package:brain_mantra/utils/constants.dart';
import 'package:brain_mantra/widgets/answer_button.dart';
import 'package:brain_mantra/widgets/diagram_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _diagramTypes = {
  PuzzleType.angleFinding,
  PuzzleType.areaVolume,
  PuzzleType.coordinateDistance,
  PuzzleType.graphReading,
};

// Non-diagram types that populate a hint (every tier, since Phase 11 -
// see puzzle.dart's hint doc comment), for the "no diagram, still shows a
// hint" half of the layout test.
const _hintedNonDiagramTypes = {
  PuzzleType.bodmas,
  PuzzleType.speedDistance,
  PuzzleType.profitLoss,
  PuzzleType.interest,
};

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

  testWidgets('tapping Skip advances to the next question without scoring',
      (tester) async {
    final controller = GameController(
      totalQuestions: 3,
      isDailyChallenge: false,
      rng: RngService.seeded('gs-skip-1'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    expect(controller.questionNumber, equals(1));
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await _pumpMillis(tester, AppDurations.feedbackDuration.inMilliseconds + 200);

    expect(controller.totalMarks, equals(0));
    expect(controller.lastOutcome, equals(AnswerOutcome.skipped));
    expect(controller.questionNumber, equals(2));
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

  testWidgets(
      'a diagram-based question renders the diagram alongside the options, '
      'plus a hint', (tester) async {
    // Every formula-driven type populates a hint at every tier (Phase 11),
    // so this only needs to seed-search for the *type*, same pattern as
    // the trueFalse case-sensitivity regression test in
    // game_controller_test.dart.
    GameController? controller;
    for (var seed = 0; seed < 200; seed++) {
      final candidate = GameController(
        totalQuestions: 10,
        isDailyChallenge: true,
        rng: RngService.seeded('gs-diagram-search-$seed'),
      );
      if (_diagramTypes.contains(candidate.currentPuzzle!.type)) {
        controller = candidate;
        break;
      }
    }
    expect(controller, isNotNull,
        reason: 'no diagram-type puzzle found in 200 seeds - unexpected');

    await tester.pumpWidget(_wrap(GameScreen(debugController: controller!)));
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((w) => w.painter is DiagramPainter),
      isTrue,
      reason: 'expected a DiagramPainter CustomPaint in the tree',
    );
    // The Row-based side-by-side layout only applies to diagram
    // questions (see _QuestionAndOptions.build's hasDiagram branch) -
    // every option button should still be present and tappable.
    for (final option in controller.currentPuzzle!.options) {
      expect(find.text(option), findsOneWidget);
    }
    expect(controller.currentPuzzle!.hint, isNotNull);
    // Hints start hidden behind a button, not shown automatically - see
    // _QuestionAndOptionsState._hintRevealed.
    expect(find.text('Watch Ad for Hint'), findsOneWidget);
    expect(find.textContaining(controller.currentPuzzle!.hint!), findsNothing);

    await tester.tap(find.text('Watch Ad for Hint'));
    await tester.pump();

    expect(find.textContaining(controller.currentPuzzle!.hint!), findsOneWidget);
    expect(find.text('Watch Ad for Hint'), findsNothing);
  });

  testWidgets(
      'a diagram-as-answer-option question (Phase 13) renders a reference '
      'diagram plus 4 rendered option shapes in a uniform grid, and '
      'tapping one selects it', (tester) async {
    GameController? controller;
    for (var seed = 0; seed < 200; seed++) {
      final candidate = GameController(
        totalQuestions: 10,
        isDailyChallenge: true,
        rng: RngService.seeded('gs-diagram-option-search-$seed'),
      );
      if (candidate.currentPuzzle!.type == PuzzleType.mirrorImage) {
        controller = candidate;
        break;
      }
    }
    expect(controller, isNotNull,
        reason: 'no mirrorImage puzzle found in 200 seeds - unexpected');

    await tester.pumpWidget(_wrap(GameScreen(debugController: controller!)));
    await tester.pump();

    // 1 reference-shape diagram + 4 option-shape diagrams = 5 total
    // DiagramPainter-backed CustomPaint widgets.
    final diagramPaints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter is DiagramPainter)
        .toList();
    expect(diagramPaints.length, equals(5));

    // Every option is its own DiagramAnswerButton (not text) - none of
    // the internal option id strings should ever be shown to the player.
    expect(find.byType(DiagramAnswerButton), findsNWidgets(4));
    for (final option in controller.currentPuzzle!.options) {
      expect(find.text(option), findsNothing);
    }

    // The reference diagram + 2x2 option grid together are taller than
    // this test's fake viewport (same as any tall content inside the
    // existing SingleChildScrollView) - scroll it into view first, same
    // as tapping any off-screen option would require on a real small
    // phone.
    final firstOption = find.byType(DiagramAnswerButton).first;
    await tester.ensureVisible(firstOption);
    await tester.pump();
    await tester.tap(firstOption);
    await tester.pump();

    expect(controller.hasSelection, isTrue);
  });

  testWidgets(
      'a hinted non-diagram question shows the hint without a diagram',
      (tester) async {
    GameController? controller;
    for (var seed = 0; seed < 200; seed++) {
      final candidate = GameController(
        totalQuestions: 10,
        isDailyChallenge: true,
        rng: RngService.seeded('gs-hint-search-$seed'),
      );
      if (_hintedNonDiagramTypes.contains(candidate.currentPuzzle!.type)) {
        controller = candidate;
        break;
      }
    }
    expect(controller, isNotNull,
        reason: 'no hinted non-diagram puzzle found in 200 seeds - unexpected');

    await tester.pumpWidget(_wrap(GameScreen(debugController: controller!)));
    await tester.pump();

    expect(controller.currentPuzzle!.diagramData, isNull);
    expect(controller.currentPuzzle!.hint, isNotNull);
    expect(find.text('Watch Ad for Hint'), findsOneWidget);

    await tester.tap(find.text('Watch Ad for Hint'));
    await tester.pump();

    expect(find.textContaining(controller.currentPuzzle!.hint!), findsOneWidget);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((w) => w.painter is DiagramPainter),
      isFalse,
    );
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
