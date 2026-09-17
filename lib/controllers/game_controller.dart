import 'package:flutter/foundation.dart';

import '../models/game_session.dart';
import '../models/puzzle.dart';
import '../models/test_session.dart';
import '../services/difficulty_curve.dart';
import '../services/puzzle_generator.dart';
import '../services/rng_service.dart';

/// The entire game-rules engine for one session: loading questions,
/// scoring answers, tracking progress, and building the final
/// [TestSession] once the session is over — either a fixed-length Daily
/// Challenge reaching its question cap, or a never-ending Play session
/// the player manually stops via [endSession]. Every widget on
/// `game_screen` is just a view over this — none of them contain game
/// logic themselves.
///
/// A [ChangeNotifier] rather than plain fields so several independent
/// widgets (the timer, the marks indicator, the answer buttons) can each
/// listen only to the parts of this they care about, instead of one big
/// screen-wide rebuild on every change.
class GameController extends ChangeNotifier {
  GameController({
    this.totalQuestions, // null = no cap (Play); a number = fixed-length (Daily Challenge passes 10)
    required this.isDailyChallenge,
    this.startingScore = 0, // Play resumes from the player's last-saved score; Daily Challenge always starts at 0
    RngService? rng,
  })  : _rng = rng ??
            (isDailyChallenge
                ? RngService.seeded(_todaySeedString())
                : RngService.free()),
        _dailySeedValue = isDailyChallenge ? _todaySeedString() : null {
    // Load the first question immediately — simpler for game_screen than
    // requiring a separate start() call, and safe to notifyListeners()
    // here even though nothing is listening yet (a no-op in that case).
    _loadNextPuzzle();
  }

  /// Null means this session never ends on its own (Play mode) — the only
  /// way out is [endSession]. A number means a fixed-length test (Daily
  /// Challenge).
  final int? totalQuestions;
  final bool isDailyChallenge;
  final int startingScore;
  final RngService _rng;

  /// Only set for a Daily Challenge — recorded so [TestSession] can carry
  /// it, matching what `GameSession.seedUsed` is for.
  final String? _dailySeedValue;

  final DateTime _startedAt = DateTime.now();

  // --- live state ---
  int _questionIndex = 0; // 0-based internally
  Puzzle? _currentPuzzle;
  String? _selectedOption; // chosen but not yet submitted
  bool _isSubmitted = false; // true while feedback is showing
  bool _isEnded = false; // set by endSession() — Play mode's manual stop

  final List<Puzzle> _puzzlesShown = [];
  final List<AnswerOutcome> _outcomes = [];
  final List<int> _marksAwarded = []; // parallel to _outcomes: +4/-2/0

  /// The last 5 puzzle TYPES shown, oldest first — used by [_pickNextType]
  /// so the same topic doesn't come back too soon. Bounded to 5 entries
  /// (see [_pickNextType]'s trim step below).
  final List<PuzzleType> _recentTypes = [];

  // --- read-only getters for the UI ---
  Puzzle? get currentPuzzle => _currentPuzzle;

  /// 1-based, for display ("Question 3 of 10").
  int get questionNumber => _questionIndex + 1;

  String? get selectedOption => _selectedOption;
  bool get hasSelection => _selectedOption != null;
  bool get isSubmitted => _isSubmitted;

  /// [startingScore] plus everything scored so far this session — this is
  /// what makes Play mode's score continue across sessions rather than
  /// always restarting at 0, while Daily Challenge (startingScore always
  /// 0) behaves exactly as before.
  int get totalMarks =>
      startingScore + _marksAwarded.fold(0, (sum, marks) => sum + marks);

  /// The outcome of the most recently submitted/skipped question — used
  /// by `game_screen` to decide which [FeedbackOverlay] variant to show.
  /// Null until the first answer is scored.
  AnswerOutcome? get lastOutcome => _outcomes.isEmpty ? null : _outcomes.last;

  /// True once [totalQuestions] questions have been answered (fixed-length
  /// Daily Challenge only — always false when [totalQuestions] is null).
  bool get isTestComplete =>
      totalQuestions != null && _questionIndex >= totalQuestions!;

  /// True once the session is over for *any* reason — reaching the
  /// question cap, or the player manually pressing End. This is what
  /// `game_screen` actually watches to decide when to navigate away.
  bool get isSessionOver => isTestComplete || _isEnded;

  /// The finished session, ready to persist/submit — only non-null once
  /// [isSessionOver] is true.
  TestSession? get finalTestSession =>
      isSessionOver ? _buildTestSession() : null;

  /// Manually stops an in-progress (never-ending, Play-mode) session — the
  /// End button's action. Whatever question is currently on screen and
  /// unanswered is simply discarded, uncounted; no penalty either way.
  void endSession() {
    if (isSessionOver) return;
    _isEnded = true;
    notifyListeners();
  }

  /// Records a tap on an option button. Only *selects* it — nothing is
  /// scored until [submitSelected] is called. Ignored once an answer has
  /// already been submitted for this question (the buttons should be
  /// disabled by then anyway; this is a defensive second guard).
  void selectOption(String option) {
    if (_isSubmitted) return;
    _selectedOption = option;
    notifyListeners();
  }

  /// Locks in whatever is currently selected. Does nothing if nothing has
  /// been selected yet — this is what keeps the Submit button meaningful
  /// as a real gate, not just a formality.
  void submitSelected() {
    if (_selectedOption == null || _isSubmitted) return;
    // Case-insensitive: PuzzleType.trueFalse's displayed options are
    // "True"/"False" (capitalized, for readability) while Dart's own
    // `bool.toString()` produces lowercase "true"/"false" — a
    // case-sensitive compare here would silently mark every true/false
    // question wrong regardless of what the player picked. Harmless for
    // every other type (numeric strings and the family-tree/shape
    // vocabularies are already consistently lowercase).
    final isCorrect = _selectedOption!.toLowerCase() ==
        _currentPuzzle!.correctAnswer.toString().toLowerCase();
    _score(isCorrect);
  }

  /// Called when the countdown reaches zero with nothing submitted yet.
  /// Scores as "skipped" (0 marks) — explicitly NOT the same as a wrong
  /// answer, per the "no penalty for running out of time" rule.
  void skipDueToTimeout() {
    if (_isSubmitted) return;
    _score(null);
  }

  /// Called when the player taps the Skip button, choosing to bypass the
  /// current question rather than wait out the timer. Scores identically
  /// to [skipDueToTimeout] (0 marks, recorded as [AnswerOutcome.skipped])
  /// — skipping is always free, whether the player or the clock decided
  /// it. A separate method (not just reusing skipDueToTimeout's name)
  /// purely for call-site clarity about *why* a question was skipped.
  void skipManually() {
    if (_isSubmitted) return;
    _score(null);
  }

  /// Records one question's outcome. [isCorrect] is null for a timeout
  /// (skipped), true/false for an actual submitted answer.
  ///
  /// Marks differ by mode: Play uses the standard +4/-2/0 system; Daily
  /// Challenge is flat +10 for correct and 0 otherwise (wrong or
  /// skipped) — deliberately no penalty, since its questions are already
  /// drawn from the hardest tiers (see `_loadNextPuzzle`).
  void _score(bool? isCorrect) {
    final outcome = isCorrect == null
        ? AnswerOutcome.skipped
        : (isCorrect ? AnswerOutcome.correct : AnswerOutcome.wrong);
    final marks = switch (outcome) {
      AnswerOutcome.correct => isDailyChallenge ? 10 : 4,
      AnswerOutcome.wrong => isDailyChallenge ? 0 : -2,
      AnswerOutcome.skipped => 0,
    };

    _puzzlesShown.add(_currentPuzzle!);
    _outcomes.add(outcome);
    _marksAwarded.add(marks);
    _isSubmitted = true;
    notifyListeners(); // game_screen mounts FeedbackOverlay in response
  }

  /// Called by `FeedbackOverlay.onAnimationComplete` once the feedback
  /// animation finishes — advances to the next question, or ends the
  /// session if that was the last one (fixed-length mode) or the player
  /// had already pressed End in the meantime.
  void onFeedbackAnimationComplete() {
    _questionIndex++;
    _selectedOption = null;
    _isSubmitted = false;

    if (isSessionOver) {
      notifyListeners(); // game_screen sees isSessionOver and navigates
      return;
    }
    _loadNextPuzzle();
  }

  /// Generates the next question. Play's difficulty tier is randomized
  /// within a score-dependent band (see `DifficultyCurve.randomTierForScore`)
  /// — negative/low scores never crash, they just land in the easiest
  /// band. Daily Challenge ignores score entirely and always draws from
  /// tier 3+ (`DifficultyCurve.randomHighTier`) — it's meant to be
  /// consistently hard, not ramped. The question category is picked ~70%
  /// math / ~30% reasoning (see `_pickNextType`), then a type uniformly
  /// within that category, excluding any type shown in the last 5
  /// questions so the same topic doesn't come back too soon.
  void _loadNextPuzzle() {
    final tier = isDailyChallenge
        ? DifficultyCurve.randomHighTier(_rng)
        : DifficultyCurve.randomTierForScore(totalMarks, _rng);
    final type = _pickNextType();
    _currentPuzzle = PuzzleGenerator.generate(tier: tier, type: type, rng: _rng);
    notifyListeners();
  }

  // A flat, uniform pick across every PuzzleType would have math questions
  // dominate once the topic library grew past ~15 math types vs. a
  // handful of reasoning types — picking the *category* first, then
  // uniformly within it, keeps the math:reasoning split under direct
  // control (see _pickNextType's 70/30 weighting) regardless of how many
  // topics either side has.
  static final List<PuzzleType> _mathTypes = PuzzleType.values
      .where((t) => _categoryOf(t) == PuzzleCategory.mathTest)
      .toList();
  static final List<PuzzleType> _reasoningTypes = PuzzleType.values
      .where((t) => _categoryOf(t) == PuzzleCategory.reasoningTest)
      .toList();

  /// Advanced math topics held back from early/low-scoring play — a brand
  /// new player sees the core topic library first; these unlock once
  /// `totalMarks` shows real progress (see _pickNextType), or immediately
  /// for Daily Challenge (already the hardest, tier 3+ only, mode).
  static const List<PuzzleType> _gatedTypes = [
    PuzzleType.logarithm,
    PuzzleType.coordinateGeometry,
    PuzzleType.progression,
    PuzzleType.unitConversion,
  ];
  static const int _gatedTypesUnlockScore = 200;

  static PuzzleCategory _categoryOf(PuzzleType type) => switch (type) {
        PuzzleType.familyTree ||
        PuzzleType.shapeIdentification ||
        PuzzleType.mirrorImage ||
        PuzzleType.paperFolding ||
        PuzzleType.figureSeries ||
        PuzzleType.seatingArrangement ||
        PuzzleType.coding ||
        PuzzleType.directionSense ||
        PuzzleType.wordPuzzle ||
        PuzzleType.analogy ||
        PuzzleType.ranking ||
        PuzzleType.statementConclusion =>
          PuzzleCategory.reasoningTest,
        _ => PuzzleCategory.mathTest,
      };

  PuzzleType _pickNextType() {
    // ~30% reasoning / ~70% math (product spec: a 7:3 ratio), replacing
    // the earlier 50/50 split now that the topic-gating below can also
    // shrink the math pool for a low-scoring player.
    final wantsReasoning = _rng.nextInt(0, 9) < 3;
    final basePool = wantsReasoning ? _reasoningTypes : _mathTypes;
    final eligiblePool = wantsReasoning
        ? basePool
        : (totalMarks > _gatedTypesUnlockScore || isDailyChallenge
            ? basePool
            : basePool.where((t) => !_gatedTypes.contains(t)).toList());

    // Exclude anything shown in the last 5 questions so a topic doesn't
    // repeat too soon. Defensive fallback to the ungated pool if that
    // would leave nothing to pick from — should never trigger given pool
    // sizes (12 reasoning / 32 math, only 4 ever gated) vs. a 5-deep
    // window, but a crash here would end the whole session.
    var candidates =
        eligiblePool.where((t) => !_recentTypes.contains(t)).toList();
    if (candidates.isEmpty) candidates = eligiblePool;
    if (candidates.isEmpty) candidates = basePool;

    final type = candidates[_rng.nextInt(0, candidates.length - 1)];
    _recentTypes.add(type);
    if (_recentTypes.length > 5) _recentTypes.removeAt(0);
    return type;
  }

  TestSession _buildTestSession() {
    final session = GameSession(
      startedAt: _startedAt,
      score: totalMarks,
      // comboMultiplier/livesRemaining are vestigial fields from the
      // original lives-based design, now unused by the marks system —
      // kept at harmless defaults rather than removed, since GameSession
      // itself is an already-tested Phase 0 model not being changed here.
      comboMultiplier: 1,
      livesRemaining: 0,
      puzzlesAnswered: List.unmodifiable(_puzzlesShown),
      correctness: List.unmodifiable(
        _outcomes.map((o) => o == AnswerOutcome.correct).toList(),
      ),
      isDailyChallenge: isDailyChallenge,
      seedUsed: _dailySeedValue,
    );
    return TestSession(
      session: session,
      outcomes: List.unmodifiable(_outcomes),
      marksAwarded: List.unmodifiable(_marksAwarded),
    );
  }
}

/// Today's date as `yyyy-MM-dd` (UTC), used to seed a Daily Challenge so
/// every player gets the identical question sequence on a given day.
String _todaySeedString() {
  final now = DateTime.now().toUtc();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
