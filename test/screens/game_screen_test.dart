import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brain_mantra/controllers/game_controller.dart';
import 'package:brain_mantra/models/app_language.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/models/test_session.dart';
import 'package:brain_mantra/screens/game_screen.dart';
import 'package:brain_mantra/screens/results_screen.dart';
import 'package:brain_mantra/services/language_controller.dart';
import 'package:brain_mantra/services/rng_service.dart';
import 'package:brain_mantra/services/storage_service.dart';
import 'package:brain_mantra/utils/constants.dart';
import 'package:brain_mantra/widgets/answer_button.dart';
import 'package:brain_mantra/widgets/diagram_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

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

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageController>(
      create: (_) => LanguageController(AppLanguage.english),
      child: MaterialApp(home: child),
    );

/// A GameController whose current puzzle answers via plain text option
/// buttons, not [DiagramAnswerButton]s (Phase 13/14 added several
/// diagram-as-answer-option types - mirrorImage, paperFolding, and
/// figureSeries' rendered shape-series sub-case - whose `options` are
/// internal, never-displayed id strings, so `find.text(option)` would
/// never match). Tests that just need *some* puzzle to tap a
/// `find.text`-findable option on search a few seeds for one, the same
/// pattern the diagram-specific tests below already use to search *for*
/// a diagram type.
GameController _textOptionController({
  required String seedPrefix,
  int? totalQuestions,
  bool isDailyChallenge = false,
  int startingScore = 0,
}) {
  for (var seed = 0; seed < 50; seed++) {
    final candidate = GameController(
      totalQuestions: totalQuestions,
      isDailyChallenge: isDailyChallenge,
      startingScore: startingScore,
      rng: RngService.seeded('$seedPrefix-$seed'),
    );
    if (candidate.currentPuzzle!.optionDiagrams == null) {
      return candidate;
    }
  }
  throw StateError('no text-option puzzle found for $seedPrefix in 50 seeds');
}

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
  // end of a test — route it to the mock in-memory backend. Pre-seeds
  // "has seen the first-use tutorial" so existing tests (which predate
  // that feature and interact with Submit/Skip/etc. directly) aren't
  // blocked by the tutorial's spotlight overlay — tests that actually
  // exercise the tutorial itself override this locally with a fresh,
  // empty SharedPreferences.
  setUp(() {
    SharedPreferences.setMockInitialValues({'has_seen_play_tutorial': true});
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
    final controller = _textOptionController(
      seedPrefix: 'gs-2',
      totalQuestions: 3,
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    final correctLabel = _correctLabel(controller.currentPuzzle!);
    // The ad placeholder card above the question now takes real height in
    // this small test viewport — scroll the option into view first, same
    // as any tall content on a real phone screen.
    await tester.ensureVisible(find.text(correctLabel));
    await tester.pump();
    await tester.tap(find.text(correctLabel));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('+4 marks'), findsOneWidget);
  });

  testWidgets(
      'tapping a wrong answer then Submit lowers the marks total',
      (tester) async {
    final controller = _textOptionController(
      seedPrefix: 'gs-4',
      totalQuestions: 3,
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    final puzzle = controller.currentPuzzle!;
    final correctLabel = _correctLabel(puzzle);
    final wrongAnswer = puzzle.options.firstWhere((o) => o != correctLabel);
    await tester.ensureVisible(find.text(wrongAnswer));
    await tester.pump();
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
    final controller = _textOptionController(
      seedPrefix: 'gs-3',
      totalQuestions: 2,
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    for (var i = 0; i < 2; i++) {
      // Later questions this session draws are just as likely to be a
      // diagram-as-answer-option type as the first - _correctLabel's
      // find.text lookup only works for the text-option kind, so skip
      // ahead (without scoring) whenever one comes up rather than
      // failing this navigation-focused test on an unrelated puzzle type.
      if (controller.currentPuzzle!.optionDiagrams != null) {
        await tester.ensureVisible(find.text('Skip'));
        await tester.pump();
        await tester.tap(find.text('Skip'));
        await tester.pump();
        await _pumpMillis(
          tester,
          AppDurations.feedbackDuration.inMilliseconds + 200,
        );
        continue;
      }
      final answer = _correctLabel(controller.currentPuzzle!);
      await tester.ensureVisible(find.text(answer));
      await tester.pump();
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
    final controller = _textOptionController(
      seedPrefix: 'gs-5',
      totalQuestions: null, // Play mode — no cap
      startingScore: 40,
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    // Answer one question first, just to prove End works mid-session, not
    // only on the very first question.
    final answer = _correctLabel(controller.currentPuzzle!);
    await tester.ensureVisible(find.text(answer));
    await tester.pump();
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
      'pressing the system/hardware back button mid-session persists the '
      'score, even though it never reaches ResultsScreen', (tester) async {
    final controller = _textOptionController(
      seedPrefix: 'gs-back',
      totalQuestions: null,
      startingScore: 40,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageController>(
        create: (_) => LanguageController(AppLanguage.english),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    final pushFuture = navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => GameScreen(debugController: controller)),
    );
    await tester.pump();
    await tester.pump();

    // Answer one question so there's something to lose if the back press
    // didn't save — an untouched session (no outcomes yet) deliberately
    // doesn't persist, so this is also what proves that path isn't what's
    // firing here.
    final answer = _correctLabel(controller.currentPuzzle!);
    await tester.ensureVisible(find.text(answer));
    await tester.pump();
    await tester.tap(find.text(answer));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await _pumpMillis(tester, AppDurations.feedbackDuration.inMilliseconds + 200);

    expect(find.text('home'), findsNothing);

    // Simulates the platform-level back button/gesture (distinct from
    // tester.pageBack(), which taps the AppBar's own back arrow — this
    // app's GameScreen has no such arrow; the system back button is the
    // only way back, routed through PopScope). Bounded pumps, not
    // pumpAndSettle — GameScreen's TimerBar/floating-numbers animations
    // never settle on their own while it's alive (same reason the "End
    // button" test above only reaches for pumpAndSettle after the
    // session has actually ended).
    await tester.binding.handlePopRoute();

    // This is the precise real bug, reproduced: home_screen.dart's
    // _navigateToGame does `await Navigator.push(...)` for this exact
    // route, then immediately re-fetches the score — so chaining
    // directly off pushFuture (not off a fixed number of test pumps)
    // asks the same question the real Home screen effectively asks. If
    // the route could pop before the persist actually finished (the old,
    // fire-and-forget bug), this would see stale/null data; it can't
    // happen anymore because the pop itself is now held open
    // (PopScope(canPop: false) in game_screen.dart) until the persist
    // completes.
    final statsRightAfterPop =
        pushFuture.then((_) => StorageService.loadStats());

    await _pumpMillis(tester, 2000, step: 20);

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(ResultsScreen), findsNothing);
    expect((await statsRightAfterPop).lastPlayedDate, isNotNull);
  });

  testWidgets(
      'the app being backgrounded (Home button / Recent Apps / OS-level '
      'switch away) mid-session persists the score too', (tester) async {
    final controller = _textOptionController(
      seedPrefix: 'gs-bg',
      totalQuestions: null,
      startingScore: 40,
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    final answer = _correctLabel(controller.currentPuzzle!);
    await tester.ensureVisible(find.text(answer));
    await tester.pump();
    await tester.tap(find.text(answer));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await _pumpMillis(tester, AppDurations.feedbackDuration.inMilliseconds + 200);

    // The Home button, Recent Apps button, and swiping the app away from
    // the task switcher all surface to Flutter the same way: the app
    // transitions to AppLifecycleState.paused. GameScreen's
    // WidgetsBindingObserver is what this exercises.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final stats = await StorageService.loadStats();
    expect(stats.lastPlayedDate, isNotNull);
  });

  testWidgets(
      'Home/Recent-Apps only minimizes — GameScreen stays mounted (no '
      'navigation to Home/Results) while the app is backgrounded',
      (tester) async {
    final controller = _textOptionController(
      seedPrefix: 'gs-bg-stays',
      totalQuestions: null,
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(ResultsScreen), findsNothing);
  });

  testWidgets(
      "the question's countdown keeps running against real time while "
      'backgrounded (not frozen/paused) — enough background time times '
      "out the question that was on screen, same as a real exam timer",
      (tester) async {
    final controller = _textOptionController(
      seedPrefix: 'gs-bg-timer',
      totalQuestions: null,
    );
    final questionNumberBefore = controller.questionNumber;
    final timeLimit = controller.currentPuzzle!.timeLimitSeconds;
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // GameScreen does nothing to stop TimerBar's countdown on
    // backgrounding (no isRunning flip, no controller.stop()) — one big
    // jump past the question's own time limit, simulating "away longer
    // than the question allowed," is enough to time it out on its own.
    await tester.pump(Duration(seconds: timeLimit + 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpMillis(tester, AppDurations.feedbackDuration.inMilliseconds + 200);

    expect(controller.questionNumber, greaterThan(questionNumberBefore));
    expect(controller.lastOutcome, equals(AnswerOutcome.skipped));
    // Still just the Play screen, minimized-and-resumed — never exited.
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets(
      'opening a session and immediately backgrounding it without '
      'answering anything does not count as "played" (no persist fires)',
      (tester) async {
    final controller = _textOptionController(seedPrefix: 'gs-bg-untouched');
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final stats = await StorageService.loadStats();
    expect(stats.lastPlayedDate, isNull);
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

  testWidgets('Daily Challenge shows an End button too, so marks are '
      "saved even if the player ends it after just one question",
      (tester) async {
    final controller = GameController(
      totalQuestions: 3,
      isDailyChallenge: true,
      rng: RngService.seeded('gs-6'),
    );
    await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
    await tester.pump();

    expect(find.text('End'), findsOneWidget);
  });

  group('first-use tutorial', () {
    testWidgets(
        'exactly 4 controls are wrapped for the walkthrough: End, Submit, '
        'Skip, Notepad', (tester) async {
      final controller = _textOptionController(seedPrefix: 'gs-tutorial-count');
      await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
      await tester.pump();

      expect(find.byType(Showcase), findsNWidgets(4));
    });

    testWidgets(
        'a never-seen player: the timer stays frozen until the '
        'walkthrough finishes (never fires onExpired even well past the '
        "question's own time limit)", (tester) async {
      // Overrides the file's default setUp (which seeds "already seen"
      // so the other tests above aren't blocked by this feature).
      SharedPreferences.setMockInitialValues({});
      final controller = _textOptionController(seedPrefix: 'gs-tutorial-fresh');
      final timeLimit = controller.currentPuzzle!.timeLimitSeconds;
      await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
      await tester.pump();

      await _pumpMillis(tester, (timeLimit + 5) * 1000, step: 200);

      // If the timer had been running, skipDueToTimeout would have fired
      // by now and recorded a skipped outcome — it never does while the
      // tutorial is still showing.
      expect(controller.lastOutcome, isNull);
    });

    testWidgets(
        'a player who has already seen the tutorial: the timer runs '
        'normally from the very first frame (no freeze)', (tester) async {
      // The file's default setUp already seeds "already seen" — this
      // test just makes that assumption explicit and verifiable, rather
      // than only relying on every other test incidentally depending on
      // it.
      final controller = _textOptionController(seedPrefix: 'gs-tutorial-seen');
      final timeLimit = controller.currentPuzzle!.timeLimitSeconds;
      await tester.pumpWidget(_wrap(GameScreen(debugController: controller)));
      await tester.pump();

      await _pumpMillis(tester, (timeLimit + 5) * 1000, step: 200);

      expect(controller.lastOutcome, equals(AnswerOutcome.skipped));
    });
  });
}
