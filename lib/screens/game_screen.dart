import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/game_controller.dart';
import '../models/age_group.dart';
import '../models/app_language.dart';
import '../models/puzzle.dart';
import '../models/player_stats.dart';
import '../models/test_session.dart';
import '../services/ad_frequency_cap.dart';
import '../services/ads_service.dart';
import '../services/auth_service.dart';
import '../services/language_controller.dart';
import '../services/leaderboard_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/streak_service.dart';
import '../utils/constants.dart';
import '../widgets/answer_button.dart';
import '../widgets/diagram_painter.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/floating_numbers_background.dart';
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
    this.ageGroupTest,
    @visibleForTesting this.debugController,
  });

  final bool isDailyChallenge;

  /// Only meaningful for Play (`isDailyChallenge: false`) — the score to
  /// resume from, fetched from the player's Supabase profile by whoever
  /// navigates here (see `home_screen.dart`). Daily Challenge always
  /// starts fresh at 0, per its fairness rules.
  final int startingScore;

  /// Non-null launches an Age-Group Test instead of Play/Daily Challenge
  /// (see `home_screen.dart`'s Age-Group Test cards) — 30 questions, a
  /// maths-only pool scoped by age group, no score/leaderboard effect.
  /// Takes precedence over [isDailyChallenge]/[startingScore], which the
  /// caller should leave at their defaults when this is set.
  final AgeGroup? ageGroupTest;

  /// Test-only hook: inject a pre-built controller (e.g. with a seeded
  /// RngService and a small totalQuestions) instead of letting this
  /// screen create its own. Real app code never sets this.
  final GameController? debugController;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
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
    _controller =
        widget.debugController ??
        GameController(
          isDailyChallenge: widget.isDailyChallenge,
          totalQuestions: widget.isDailyChallenge
              ? dailyChallengeQuestionCount
              : null,
          startingScore: widget.isDailyChallenge ? 0 : widget.startingScore,
          ageGroupTest: widget.ageGroupTest,
          // One-time read (not `watch`) — language is fixed for this
          // whole session's lifetime, same as ageGroupTest; a mid-session
          // change via Settings only affects the next session started.
          language: context.read<LanguageController>().language,
        );
    _lastSeenQuestionNumber = _controller.questionNumber;
    _controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Safety net for "the app got backgrounded/killed mid-session" (no
  /// clean shutdown hook exists for that — `paused` is the closest
  /// Flutter/Android gives us, firing when the app is sent to the
  /// background, which is also the step before a swipe-kill). Persists
  /// whatever's been scored so far; never navigates (the app is leaving
  /// regardless) and never fires if nothing's actually been answered yet
  /// (opening a session and immediately backgrounding shouldn't count as
  /// "played" for streak/Daily-Challenge-lock purposes).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    if (_hasNavigatedToResults || _controller.isSessionOver) return;
    final snapshot = _controller.currentProgressSnapshot;
    if (snapshot.outcomes.isEmpty) return;
    _persistScoreAndStats(snapshot);
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

  /// The shared "sync score/stats" core of ending a session — split out
  /// of `_persistAndShowResults` so it can also run, on its own, as a
  /// safety net when the player exits mid-session (back button) or the
  /// app gets backgrounded/killed before a normal end would otherwise
  /// have fired it: either way, whatever's been scored *so far* is never
  /// silently lost. Never navigates — callers that need to (the normal
  /// end-of-session path) do that themselves with the returned values.
  Future<({int updatedScore, PlayerStats stats, int previousHighScore})>
  _persistScoreAndStats(TestSession testSession) async {
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

    // Wrapped in try/catch: local persistence must succeed regardless of
    // Supabase reachability (offline, a dropped connection, or — in
    // widget tests — Supabase never being initialized at all). Losing
    // one score-sync isn't nearly as bad as getting stuck over a failed
    // network call.
    // An Age-Group Test never touches score/leaderboard at all, per the
    // feature plan — not even the internal marks this session racked up
    // (which exist only so the pass/fail % can be computed on
    // results_screen; see its correctCount-based calculation, not marks).
    final isAgeGroupTest = _controller.ageGroupTest != null;

    try {
      if (isAgeGroupTest) {
        // Intentionally no score/leaderboard call at all.
      } else if (_controller.isDailyChallenge) {
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
      // Every session (any mode, Age-Group Test included) marks the
      // player as active — this is what the 30-day inactive-account
      // deletion job checks.
      await AuthService.touchLastActive();
    } catch (_) {
      // Best-effort sync — local stats (below) are the source of truth
      // for what the player sees right now regardless of whether this
      // succeeded. updatedScore keeps its pre-try default in this case.
    }

    final currentStats = await StorageService.loadStats();
    // An Age-Group Test's internal marks tally must never count towards
    // highScore — it isn't a real score at all for this mode.
    final isNewHighScore =
        !isAgeGroupTest && updatedScore > currentStats.highScore;
    // lastPlayedDate/currentStreakDays are updated for every session end,
    // any mode — a streak day means "played at all today," not
    // "completed a Daily Challenge." UTC (not local) to match
    // GameController's own day boundary for Daily Challenge's seed.
    final playedAt = DateTime.now().toUtc();
    final newStreakDays = StreakService.nextStreakDays(
      previousStreakDays: currentStats.currentStreakDays,
      lastPlayedDate: currentStats.lastPlayedDate,
      now: playedAt,
    );
    final newStats = PlayerStats(
      highScore: isNewHighScore ? updatedScore : currentStats.highScore,
      currentStreakDays: newStreakDays,
      lastPlayedDate: playedAt,
      totalCoins: currentStats.totalCoins,
      bestScoreByTier: currentStats.bestScoreByTier,
      lastDailyChallengeDate: _controller.isDailyChallenge
          ? playedAt
          : currentStats.lastDailyChallengeDate,
    );
    await StorageService.saveStats(newStats);
    // Best-effort, same precedent as everything else here — state just
    // changed, so reminders must reflect it immediately rather than
    // waiting for the next Home visit.
    try {
      await NotificationService.rescheduleAll(
        stats: newStats,
        dailyChallengeDoneToday:
            NotificationService.isDailyChallengeDoneToday(newStats, playedAt),
        now: playedAt,
      );
    } catch (_) {
      // Never let a notification-scheduling failure strand the player.
    }

    return (
      updatedScore: updatedScore,
      stats: newStats,
      previousHighScore: currentStats.highScore,
    );
  }

  Future<void> _persistAndShowResults() async {
    final testSession = _controller.finalTestSession!;
    await StorageService.saveSession(testSession.session);
    final result = await _persistScoreAndStats(testSession);

    if (!mounted) return;
    // Captured before pushReplacement disposes _controller (see dispose()
    // below) — Continue Playing needs these to resume from the right spot.
    final isDailyChallenge = _controller.isDailyChallenge;
    final ageGroupTest = _controller.ageGroupTest;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          testSession: testSession,
          currentScore: result.updatedScore,
          previousHighScore: result.previousHighScore,
          ageGroupTest: ageGroupTest,
          onPlayAgain: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                isDailyChallenge: isDailyChallenge,
                // Resume from the just-updated cumulative score, not the
                // score this session originally started from.
                startingScore: isDailyChallenge ? 0 : result.updatedScore,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  // Guards _persistProgressOnPop against firing more than once if the
  // player mashes back while the first pop is still waiting on the
  // persist below.
  bool _isPoppingBack = false;

  /// Back button/gesture mid-session: the same safety net as
  /// [didChangeAppLifecycleState], for the other common way to leave
  /// without going through End/question-completion.
  ///
  /// Real bug caught on-device: this used to fire-and-forget the persist
  /// so the pop itself stayed instantly responsive — but `home_screen.dart`'s
  /// `_navigateToGame` awaits the very same `Navigator.push` this pop
  /// completes, and re-fetches the score the instant that await resolves.
  /// With an un-awaited persist, the pop (and thus Home's re-fetch) could
  /// — and on-device, did — complete before `AuthService.updateCurrentScore`
  /// had actually finished, showing a stale/zero score on Home and the
  /// Leaderboard right after backing out of a scored session. Now the pop
  /// is held (`PopScope(canPop: false)` below) until the persist genuinely
  /// finishes, then performed manually — same "wait, then leave" pattern
  /// the normal End-of-session flow already uses via `pushReplacement`.
  Future<void> _persistProgressOnPop() async {
    if (_isPoppingBack) return;
    _isPoppingBack = true;
    if (!_hasNavigatedToResults && !_controller.isSessionOver) {
      final snapshot = _controller.currentProgressSnapshot;
      if (snapshot.outcomes.isNotEmpty) {
        await _persistScoreAndStats(snapshot);
      }
    }
    // _hasNavigatedToResults may have flipped true while the above was
    // awaiting (e.g. the session happened to end on its own right as back
    // was pressed) — in that case pushReplacement is already handling
    // navigation itself, so popping here too would remove an extra route.
    if (!mounted || _hasNavigatedToResults) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // false, not true: the pop must wait for _persistProgressOnPop's
      // save to actually finish (see its doc comment) before the route
      // is really removed — canPop: true would let the system pop
      // through immediately, racing the persist exactly like the bug
      // this replaced.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _persistProgressOnPop();
      },
      child: ChangeNotifierProvider<GameController>.value(
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
      // Fallback solid color (shown for an instant before the gradient
      // below paints, and wherever the gradient doesn't reach) — a light
      // green-to-light-blue gradient is the actual Play-screen background,
      // deliberately distinct from Home/End's flat AppColors.background:
      // this is the screen a player spends the most sustained focus time
      // on, so it gets its own calmer, two-tone field.
      backgroundColor: AppColors.playBackgroundBottom,
      appBar: AppBar(
        title: Text(
          controller.isDailyChallenge
              ? _t(controller.language, 'Daily Challenge', 'दैनिक चुनौती')
              : _t(controller.language, 'Play', 'खेलें'),
        ),
        actions: [
          // Now shown in every mode, including Daily Challenge — by
          // explicit product decision, exiting early must still update
          // the player's marks (not discard them), and that only happens
          // if there's an actual in-app way to end deliberately. For
          // Daily Challenge specifically, ending early also locks it for
          // the rest of the day the same as finishing it normally — see
          // `_persistAndShowResults`'s `lastDailyChallengeDate` write.
          TextButton(
            onPressed: controller.endSession,
            child: Text(
              _t(controller.language, 'End', 'समाप्त करें'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.playBackgroundTop,
                    AppColors.playBackgroundBottom,
                  ],
                ),
              ),
            ),
          ),
          // A smaller glyph count than Home ever used — subtle enough to
          // not compete with the question card/options in front of it.
          const Positioned.fill(
            child: FloatingNumbersBackground(glyphCount: 10),
          ),
          SafeArea(
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
                  // superseded reasoning). showPlaceholder: true so this slot
                  // shows the same designed "Your Ad Here" card Home uses
                  // (rather than collapsing to nothing) whenever no real ad
                  // has loaded yet.
                  AdsService.instance.bannerAdWidget(showPlaceholder: true),
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
                    isRunning:
                        !controller.isSubmitted && !controller.isHintAdPlaying,
                    onExpired: controller.skipDueToTimeout,
                    extraSeconds: controller.hintBonusSeconds,
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
                              key: ValueKey(
                                'feedback-${controller.questionNumber}',
                              ),
                              kind: _feedbackKindFor(controller.lastOutcome!),
                              correctAnswerText: puzzle.correctAnswer
                                  .toString(),
                              correctAnswerLetter: _correctOptionLetter(puzzle),
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
                          onPressed: controller.isSubmitted
                              ? null
                              : controller.skipManually,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                          ),
                          child: Text(_t(controller.language, 'Skip', 'छोड़ें')),
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
        ],
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
    final hasDiagramOptions = puzzle.optionDiagrams != null;
    final hasDiagram = puzzle.diagramData != null && !hasDiagramOptions;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // Always stretch, not just when a diagram is present — every
        // option layout (including the plain no-diagram list) is now a
        // left-aligned, full-width block for a consistent look across
        // the whole Play screen.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // clipBehavior: Clip.none so the topic badge below can overlap
          // the card's top border (half in, half out) without being cut
          // off — a small `margin`/`padding` split on the card itself is
          // what makes room for it without ever touching the question
          // text.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.silver, width: 1.5),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text(
                  puzzle.questionText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppText.question,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      topicLabel(puzzle.type, controller.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (puzzle.hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _hintRevealed ? _buildHintText(puzzle.hint!) : _buildHintButton(),
          ],
          const SizedBox(height: AppSpacing.md),
          // Three layouts: (1) diagram-as-answer-option (Phase 13) — a
          // reference shape, if any, then a uniform 2x2 grid of rendered
          // option-shapes; (2) diagram-in-question, plain text options
          // (Phase 8 Stage 1) — options left, diagram right; (3) every
          // other question type's plain centered single-column list.
          if (hasDiagramOptions)
            _buildDiagramOptions()
          else if (hasDiagram)
            _buildOptionsWithDiagram()
          else
            _buildOptionsOnly(),
        ],
      ),
    );
  }

  Widget _buildHintButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _revealHintViaRewardedAd,
        icon: const Icon(Icons.ondemand_video, size: 16),
        label: Text(
          _t(controller.language, 'Watch Ad for Hint', 'हिंट के लिए विज्ञापन देखें'),
        ),
        style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
      ),
    );
  }

  /// Prefers watching a rewarded ad to unlock the hint — but never hard-
  /// blocks on it: if no ad happens to be ready (a load in flight, a
  /// network hiccup, consent not yet resolved), the hint still reveals
  /// for free. Same "ads are best-effort, never load-bearing" precedent
  /// `AdsService` already applies everywhere else; a hint is a nice-to-
  /// have, not something worth stranding a player over.
  ///
  /// While the ad plays, the question timer is paused (via
  /// `controller.isHintAdPlaying`) and the reward adds 60 bonus seconds
  /// (`controller.hintBonusSeconds`) — both live on GameController since
  /// TimerBar is a sibling widget, not a descendant, of this one.
  void _revealHintViaRewardedAd() {
    controller.setHintAdPlaying(true);
    final shown = AdsService.instance.showRewardedIfLoaded(
      onReward: () {
        controller.addHintBonusSeconds(60);
        if (mounted) setState(() => _hintRevealed = true);
      },
      // Fires whether the ad was watched fully or closed early — this is
      // what always lifts the pause, regardless of onReward.
      onDismissed: () => controller.setHintAdPlaying(false),
    );
    if (!shown) {
      controller.setHintAdPlaying(false);
      setState(() => _hintRevealed = true);
    }
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < puzzle.options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: AnswerButton(
              letter: String.fromCharCode(65 + i),
              label: puzzle.options[i],
              state: _stateFor(puzzle.options[i]),
              onTap: controller.isSubmitted
                  ? null
                  : () => controller.selectOption(puzzle.options[i]),
            ),
          ),
      ],
    );
  }

  /// Phase 13: renders `puzzle.optionDiagrams` as a uniform 2x2 grid of
  /// square boxes (via `AspectRatio` on every cell, same as
  /// `DiagramAnswerButton`'s own doc comment describes) — every option is
  /// the exact same size and shape regardless of the underlying figure,
  /// so nothing here can end up looking irregular. The optional reference
  /// shape (`puzzle.diagramData` — e.g. the original, un-mirrored figure)
  /// sits above the grid in the same bordered-frame style
  /// `_buildOptionsWithDiagram` already uses for its question diagram.
  Widget _buildDiagramOptions() {
    return Column(
      children: [
        if (puzzle.diagramData != null) ...[
          Container(
            width: 160,
            height: 120,
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
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.silver, thickness: 1.5),
          const SizedBox(height: AppSpacing.sm),
        ],
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.silver, width: 1.5),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
            children: [
              for (var i = 0; i < puzzle.options.length; i++)
                DiagramAnswerButton(
                  letter: String.fromCharCode(65 + i),
                  diagram: puzzle.optionDiagrams![i],
                  state: _stateFor(puzzle.options[i]),
                  onTap: controller.isSubmitted
                      ? null
                      : () => controller.selectOption(puzzle.options[i]),
                ),
            ],
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
              for (var i = 0; i < puzzle.options.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: AnswerButton(
                    letter: String.fromCharCode(65 + i),
                    label: puzzle.options[i],
                    state: _stateFor(puzzle.options[i]),
                    onTap: controller.isSubmitted
                        ? null
                        : () => controller.selectOption(puzzle.options[i]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const VerticalDivider(
          color: AppColors.silver,
          thickness: 1.5,
          width: 1,
        ),
        const SizedBox(width: AppSpacing.sm),
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

/// The correct option's letter ("A"/"B"/"C"/"D"...) — same
/// index-into-`options` convention `_QuestionAndOptionsState` uses to
/// label every answer button, re-derived here so the wrong-answer
/// reveal names the same letter the player actually saw on screen.
String _correctOptionLetter(Puzzle puzzle) {
  final index = puzzle.options.indexOf(puzzle.correctAnswer.toString());
  // Defensive: should never happen (every generator's correctAnswer is
  // one of its own options), but never crash the feedback overlay over
  // it — fall back to naming the first option rather than throwing.
  return String.fromCharCode(65 + (index < 0 ? 0 : index));
}

/// Picks [en] or [hi] depending on [language] — this screen's share of
/// UI chrome is small enough that a shared `AppStrings` dictionary class
/// wasn't worth it here; a one-line helper keeps every call site terse.
String _t(AppLanguage language, String en, String hi) =>
    language == AppLanguage.english ? en : hi;
