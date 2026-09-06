import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/game_controller.dart';
import '../models/puzzle.dart';
import '../models/player_stats.dart';
import '../models/test_session.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/answer_button.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/marks_indicator.dart';
import '../widgets/submit_button.dart';
import '../widgets/timer_bar.dart';
import 'results_screen.dart';

/// The actual gameplay screen: pulls questions from [GameController],
/// renders them with select-then-submit answer buttons, a countdown, and
/// feedback — looping until the test is complete, then persisting the
/// result and navigating to [ResultsScreen].
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.isDailyChallenge = false,
    @visibleForTesting this.debugController,
  });

  final bool isDailyChallenge;

  /// Test-only hook: inject a pre-built controller (e.g. with a seeded
  /// RngService and a small totalQuestions) instead of letting this
  /// screen create its own. Real app code never sets this.
  final GameController? debugController;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  bool _hasNavigatedToResults = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.debugController ??
        GameController(isDailyChallenge: widget.isDailyChallenge);
    _controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (_controller.isTestComplete && !_hasNavigatedToResults) {
      _hasNavigatedToResults = true;
      // Deferred to after the current frame: this listener fires from
      // inside GameController.notifyListeners(), and navigating away
      // mid-notification (rather than once the frame settles) risks
      // "build scheduled during build" errors.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _persistAndShowResults();
      });
    }
  }

  Future<void> _persistAndShowResults() async {
    final testSession = _controller.finalTestSession!;
    await StorageService.saveSession(testSession.session);

    final currentStats = await StorageService.loadStats();
    final isNewHighScore = testSession.totalMarks > currentStats.highScore;
    // lastPlayedDate is updated regardless of whether this was a new high
    // score — full day-streak logic (increment/reset based on the gap
    // since the previous play date) is Phase 3 scope; this just keeps
    // the raw date current so that logic has something to build on.
    await StorageService.saveStats(PlayerStats(
      highScore: isNewHighScore ? testSession.totalMarks : currentStats.highScore,
      currentStreakDays: currentStats.currentStreakDays,
      lastPlayedDate: DateTime.now(),
      totalCoins: currentStats.totalCoins,
      bestScoreByTier: currentStats.bestScoreByTier,
    ));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        testSession: testSession,
        previousHighScore: currentStats.highScore,
        onPlayAgain: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(isDailyChallenge: widget.isDailyChallenge),
          ),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>.value(
      value: _controller,
      child: Consumer<GameController>(
        builder: (context, controller, _) {
          final puzzle = controller.currentPuzzle;
          // Between the last question finishing and the post-frame
          // navigation above actually firing, there's nothing sensible
          // to render yet — a brief loading state covers that gap.
          if (puzzle == null || controller.isTestComplete) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _GameScreenBody(controller: controller, puzzle: puzzle);
        },
      ),
    );
  }
}

class _GameScreenBody extends StatelessWidget {
  const _GameScreenBody({required this.controller, required this.puzzle});

  final GameController controller;
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(controller.isDailyChallenge ? 'Daily Challenge' : 'Play'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              MarksIndicator(
                currentQuestionNumber: controller.questionNumber,
                totalQuestions: controller.totalQuestions,
                marksSoFar: controller.totalMarks,
              ),
              const SizedBox(height: AppSpacing.md),
              TimerBar(
                // A new key per question gives each one a fresh,
                // correctly-timed countdown automatically — see
                // timer_bar.dart's own doc comment.
                key: ValueKey(puzzle.id),
                durationSeconds: puzzle.timeLimitSeconds,
                isRunning: !controller.isSubmitted,
                onExpired: controller.skipDueToTimeout,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Stack(
                  children: [
                    _QuestionAndOptions(controller: controller, puzzle: puzzle),
                    if (controller.isSubmitted)
                      Positioned.fill(
                        child: FeedbackOverlay(
                          // A fresh key per question so a new overlay
                          // (and its AnimationController) is created
                          // each time, rather than reusing stale state.
                          key: ValueKey('feedback-${controller.questionNumber}'),
                          kind: _feedbackKindFor(controller.lastOutcome!),
                          onAnimationComplete:
                              controller.onFeedbackAnimationComplete,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SubmitButton(
                hasSelection: controller.hasSelection,
                onSubmit: controller.submitSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionAndOptions extends StatelessWidget {
  const _QuestionAndOptions({required this.controller, required this.puzzle});

  final GameController controller;
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            puzzle.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppText.question,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final option in puzzle.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: AnswerButton(
                label: option,
                state: _stateFor(option),
                onTap: controller.isSubmitted
                    ? null
                    : () => controller.selectOption(option),
              ),
            ),
        ],
      ),
    );
  }

  /// Decides one option button's visual state: before submission, only
  /// whether it's the currently-selected pick; after submission, reveal
  /// which was actually correct and which (wrong) one was tapped.
  AnswerButtonState _stateFor(String option) {
    if (!controller.isSubmitted) {
      return option == controller.selectedOption
          ? AnswerButtonState.selected
          : AnswerButtonState.normal;
    }
    final correctOptionText = puzzle.correctAnswer.toString();
    if (option == correctOptionText) return AnswerButtonState.correct;
    if (option == controller.selectedOption) return AnswerButtonState.wrong;
    return AnswerButtonState.disabled;
  }
}

FeedbackKind _feedbackKindFor(AnswerOutcome outcome) => switch (outcome) {
      AnswerOutcome.correct => FeedbackKind.correct,
      AnswerOutcome.wrong => FeedbackKind.wrong,
      AnswerOutcome.skipped => FeedbackKind.neutral,
    };
