import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/game_controller.dart';
import '../models/puzzle.dart';
import '../models/player_stats.dart';
import '../models/test_session.dart';
import '../services/ad_frequency_cap.dart';
import '../services/ads_service.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/storage_service.dart';
import '../services/streak_service.dart';
import '../utils/constants.dart';
import '../widgets/answer_button.dart';
import '../widgets/diagram_painter.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/marks_indicator.dart';
import '../widgets/submit_button.dart';
import '../widgets/timer_bar.dart';
import 'results_screen.dart';

/// The actual gameplay screen: pulls questions from [GameController],
/// renders them with select-then-submit answer buttons, a countdown, and
/// feedback — looping until the test is complete, then persisting the
/// result and navigating to [ResultsScreen].
/// Daily Challenge's fixed question count — TUNABLE, matches
/// GameController's original default before totalQuestions became
/// nullable to support Play's no-cap mode.
const int dailyChallengeQuestionCount = 10;

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.isDailyChallenge = false,
    this.startingScore = 0,
    @visibleForTesting this.debugController,
  });

  final bool isDailyChallenge;

  /// Only meaningful for Play (`isDailyChallenge: false`) — the score to
  /// resume from, fetched from the player's Supabase profile by whoever
  /// navigates here (see `home_screen.dart`). Daily Challenge always
  /// starts fresh at 0, per its fairness rules.
  final int startingScore;

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

  // Interstitial ads: fire at most once every N questions answered, in
  // either mode — see ARCHITECTURE.md's Phase 4 write-up for why this is
  // question-count-based rather than round/session-based (Play has no
  // natural "round-end" short of the End button, which could be a very
  // long time away).
  final AdFrequencyCap _adFrequencyCap = AdFrequencyCap();
  late int _lastSeenQuestionNumber;

  @override
  void initState() {
    super.initState();
    _controller = widget.debugController ??
        GameController(
          isDailyChallenge: widget.isDailyChallenge,
          totalQuestions:
              widget.isDailyChallenge ? dailyChallengeQuestionCount : null,
          startingScore: widget.isDailyChallenge ? 0 : widget.startingScore,
        );
    _lastSeenQuestionNumber = _controller.questionNumber;
    _controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (_controller.questionNumber != _lastSeenQuestionNumber) {
      // A question was just completed and the controller moved to the
      // next one (or ended) — the one point-in-time this screen can tell
      // "a question just finished" from outside GameController itself.
      _lastSeenQuestionNumber = _controller.questionNumber;
      _maybeShowInterstitial();
    }
    if (_controller.isSessionOver && !_hasNavigatedToResults) {
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

  /// Shows an interstitial only between questions (never mid-countdown,
  /// never on load/exit — see Google's own interstitial placement policy
  /// cited in ARCHITECTURE.md's Phase 4 write-up), and only when the
  /// session isn't also ending on this exact transition — an interstitial
  /// must never stack in front of the results-screen navigation.
  void _maybeShowInterstitial() {
    _adFrequencyCap.recordQuestionAnswered();
    if (_controller.isSessionOver || !_adFrequencyCap.isDue) return;
    AdsService.instance.showInterstitialIfLoaded(
      onDismissed: _adFrequencyCap.recordAdShown,
    );
  }

  Future<void> _persistAndShowResults() async {
    final testSession = _controller.finalTestSession!;
    await StorageService.saveSession(testSession.session);

    // Only Daily Challenge results are ranked — a "Play" session uses
    // freely-random questions, so it isn't a fair, comparable test across
    // players the way a shared-seed Daily Challenge is (see the plan's
    // rationale in ARCHITECTURE.md's Phase 2 amendment). Local stats
    // still save for both modes, below.
    //
    // Reads _controller.isDailyChallenge (not widget.isDailyChallenge) —
    // the controller is the authoritative source, since a test-injected
    // debugController's own flag could otherwise diverge from the
    // widget's separate constructor parameter.
    //
    // Daily Challenge no longer keeps an isolated score of its own — its
    // marks (tier 3+, +10/no-penalty, scored by GameController) are a
    // bonus added straight onto the same persistent Play score, so
    // "regular play" is the one running total that matters either way.
    // Defaults to the cumulative Play total; only overwritten below if
    // this is a Daily Challenge and the fetch+add succeeds.
    var updatedScore = testSession.session.score;

    // Wrapped in try/catch: local persistence and navigation must succeed
    // regardless of Supabase reachability (offline, a dropped connection,
    // or — in widget tests — Supabase never being initialized at all).
    // Losing one score-sync isn't nearly as bad as getting stuck on this
    // screen because a network call failed.
    try {
      if (_controller.isDailyChallenge) {
        await LeaderboardService.submitDailyResult(
          marks: testSession.totalMarks,
          // Daily Challenge always sets a fixed totalQuestions (see
          // initState) — dailyChallengeQuestionCount avoids a
          // force-unwrap of the nullable field here.
          questionsTotal: dailyChallengeQuestionCount,
        );
        final baseScore = await AuthService.fetchCurrentScore();
        updatedScore = baseScore + testSession.totalMarks;
        await AuthService.updateCurrentScore(updatedScore);
      } else {
        // Play mode: persist the new running total to the player's
        // account so their next Play session resumes from exactly here,
        // not 0. testSession.session.score is the cumulative figure
        // (startingScore + everything earned this session) — deliberately
        // not testSession.totalMarks, which is only this session's delta
        // and would silently discard the starting score.
        await AuthService.updateCurrentScore(updatedScore);
      }
      // Every session (either mode) marks the player as active — this is
      // what the 30-day inactive-account deletion job checks.
      await AuthService.touchLastActive();
    } catch (_) {
      // Best-effort sync — local stats (below) are the source of truth
      // for what the player sees right now regardless of whether this
      // succeeded. updatedScore keeps its pre-try default in this case.
    }

    final currentStats = await StorageService.loadStats();
    final isNewHighScore = updatedScore > currentStats.highScore;
    // lastPlayedDate/currentStreakDays are updated for every session end,
    // either mode — a streak day means "played at all today," not
    // "completed a Daily Challenge." UTC (not local) to match
    // GameController's own day boundary for Daily Challenge's seed.
    final playedAt = DateTime.now().toUtc();
    final newStreakDays = StreakService.nextStreakDays(
      previousStreakDays: currentStats.currentStreakDays,
      lastPlayedDate: currentStats.lastPlayedDate,
      now: playedAt,
    );
    await StorageService.saveStats(PlayerStats(
      highScore: isNewHighScore ? updatedScore : currentStats.highScore,
      currentStreakDays: newStreakDays,
      lastPlayedDate: playedAt,
      totalCoins: currentStats.totalCoins,
      bestScoreByTier: currentStats.bestScoreByTier,
    ));

    if (!mounted) return;
    // Captured before pushReplacement disposes _controller (see dispose()
    // below) — Continue Playing needs these to resume from the right spot.
    final isDailyChallenge = _controller.isDailyChallenge;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        testSession: testSession,
        currentScore: updatedScore,
        previousHighScore: currentStats.highScore,
        onPlayAgain: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              isDailyChallenge: isDailyChallenge,
              // Resume from the just-updated cumulative score, not the
              // score this session originally started from.
              startingScore: isDailyChallenge ? 0 : updatedScore,
            ),
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
          // Between the session ending (question cap reached, or the
          // player pressed End) and the post-frame navigation above
          // actually firing, there's nothing sensible to render yet — a
          // brief loading state covers that gap.
          if (puzzle == null || controller.isSessionOver) {
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
        actions: [
          // Play only — it's the never-ending mode, so it needs an
          // explicit way to stop. Daily Challenge already has a natural
          // end (its fixed question count) and isn't offered an early
          // exit here.
          if (!controller.isDailyChallenge)
            TextButton(
              onPressed: controller.endSession,
              child: const Text('End', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // Trimmed from AppSpacing.lg - every bit of vertical room here
          // helps keep a full question + options on-screen without
          // scrolling, now that a banner ad also sits above the marks bar.
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              // Banner: very top of the screen, above the marks/timer bar
              // — by explicit product decision (this was previously
              // Home-only; see ARCHITECTURE.md's Phase 4 write-up for the
              // superseded reasoning).
              AdsService.instance.bannerAdWidget(),
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
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Stack(
                  children: [
                    _QuestionAndOptions(
                      // A fresh key per question resets the hint-revealed
                      // state below — otherwise Flutter would reuse the
                      // same State object (and its "hint already shown"
                      // flag) across an unrelated new question.
                      key: ValueKey('question-${puzzle.id}'),
                      controller: controller,
                      puzzle: puzzle,
                    ),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          controller.isSubmitted ? null : controller.skipManually,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: SubmitButton(
                      hasSelection: controller.hasSelection,
                      onSubmit: controller.submitSelected,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionAndOptions extends StatefulWidget {
  const _QuestionAndOptions({
    super.key,
    required this.controller,
    required this.puzzle,
  });

  final GameController controller;
  final Puzzle puzzle;

  @override
  State<_QuestionAndOptions> createState() => _QuestionAndOptionsState();
}

class _QuestionAndOptionsState extends State<_QuestionAndOptions> {
  // Hints start hidden — a button reveals them on tap, rather than
  // showing the formula/theorem name automatically, so the player tries
  // first. Reset per question via this widget's ValueKey(puzzle.id) in
  // game_screen.dart, which forces a fresh State (and thus this flag)
  // each time the puzzle changes.
  bool _hintRevealed = false;

  GameController get controller => widget.controller;
  Puzzle get puzzle => widget.puzzle;

  @override
  Widget build(BuildContext context) {
    final hasDiagram = puzzle.diagramData != null;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            hasDiagram ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          Text(
            puzzle.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppText.question,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (puzzle.hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _hintRevealed ? _buildHintText(puzzle.hint!) : _buildHintButton(),
          ],
          const SizedBox(height: AppSpacing.md),
          // The diagram sits after the question, side-by-side with the
          // options rather than stacked above them — options left
          // (left-aligned), diagram right. Every non-diagram question
          // type keeps the plain centered single-column layout below.
          if (hasDiagram) _buildOptionsWithDiagram() else _buildOptionsOnly(),
        ],
      ),
    );
  }

  Widget _buildHintButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () => setState(() => _hintRevealed = true),
        icon: const Icon(Icons.lightbulb_outline, size: 16),
        label: const Text('Show hint'),
        style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
      ),
    );
  }

  Widget _buildHintText(String hint) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.neutral),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsOnly() {
    return Column(
      children: [
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
    );
  }

  Widget _buildOptionsWithDiagram() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          // stretch (not just start) so every button shares the same left
          // AND right edge — a clean left-hand block, not ragged-width
          // buttons merely hugging the left side.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          // A visible frame around the diagram, plus a hard ClipRect —
          // DiagramPainter itself now fits every shape to the box it's
          // actually given (see its own doc comment), but the frame+clip
          // here is a backstop: nothing painted can ever visually escape
          // this box, regardless of any future edge case in the painter.
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.silver, width: 1.5),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: ClipRect(
              child: CustomPaint(painter: DiagramPainter(puzzle.diagramData!)),
            ),
          ),
        ),
      ],
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
