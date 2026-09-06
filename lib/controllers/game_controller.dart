import 'package:flutter/foundation.dart';

import '../models/game_session.dart';
import '../models/puzzle.dart';
import '../models/test_session.dart';
import '../services/difficulty_curve.dart';
import '../services/puzzle_generator.dart';
import '../services/rng_service.dart';

/// The entire game-rules engine for one test: loading questions, scoring
/// answers, tracking progress, and building the final [TestSession] once
/// all questions are done. Every widget on `game_screen` is just a view
/// over this — none of them contain game logic themselves.
///
/// A [ChangeNotifier] rather than plain fields so several independent
/// widgets (the timer, the marks indicator, the answer buttons) can each
/// listen only to the parts of this they care about, instead of one big
/// screen-wide rebuild on every change.
class GameController extends ChangeNotifier {
  GameController({
    this.totalQuestions = 10, // TUNABLE — no question-count spec exists
    required this.isDailyChallenge,
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

  final int totalQuestions;
  final bool isDailyChallenge;
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

  final List<Puzzle> _puzzlesShown = [];
  final List<AnswerOutcome> _outcomes = [];
  final List<int> _marksAwarded = []; // parallel to _outcomes: +4/-2/0

  // --- read-only getters for the UI ---
  Puzzle? get currentPuzzle => _currentPuzzle;

  /// 1-based, for display ("Question 3 of 10").
  int get questionNumber => _questionIndex + 1;

  String? get selectedOption => _selectedOption;
  bool get hasSelection => _selectedOption != null;
  bool get isSubmitted => _isSubmitted;

  int get totalMarks => _marksAwarded.fold(0, (sum, marks) => sum + marks);

  /// The outcome of the most recently submitted/skipped question — used
  /// by `game_screen` to decide which [FeedbackOverlay] variant to show.
  /// Null until the first answer is scored.
  AnswerOutcome? get lastOutcome => _outcomes.isEmpty ? null : _outcomes.last;

  bool get isTestComplete => _questionIndex >= totalQuestions;

  /// The finished test, ready to persist/submit — only non-null once
  /// [isTestComplete] is true.
  TestSession? get finalTestSession =>
      isTestComplete ? _buildTestSession() : null;

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

  /// Records one question's outcome. [isCorrect] is null for a timeout
  /// (skipped), true/false for an actual submitted answer.
  void _score(bool? isCorrect) {
    final outcome = isCorrect == null
        ? AnswerOutcome.skipped
        : (isCorrect ? AnswerOutcome.correct : AnswerOutcome.wrong);
    final marks = switch (outcome) {
      AnswerOutcome.correct => 4,
      AnswerOutcome.wrong => -2,
      AnswerOutcome.skipped => 0,
    };

    _puzzlesShown.add(_currentPuzzle!);
    _outcomes.add(outcome);
    _marksAwarded.add(marks);
    _isSubmitted = true;
    notifyListeners(); // game_screen mounts FeedbackOverlay in response
  }

  /// Called by `FeedbackOverlay.onAnimationComplete` once the feedback
  /// animation finishes — advances to the next question, or finishes the
  /// test if that was the last one.
  void onFeedbackAnimationComplete() {
    _questionIndex++;
    _selectedOption = null;
    _isSubmitted = false;

    if (isTestComplete) {
      notifyListeners(); // game_screen sees isTestComplete and navigates
      return;
    }
    _loadNextPuzzle();
  }

  /// Generates the next question. Difficulty is looked up from the
  /// running marks total (reusing Phase 1's DifficultyCurve unchanged —
  /// tierForScore already treats a negative score as tier 1, so an early
  /// wrong answer's -2 doesn't need special-casing here). The question
  /// type is picked uniformly at random across all 8 types (mixed
  /// math/reasoning pool — the mode confirmed during Phase 2 planning),
  /// with a light one-reroll anti-repeat so the same type rarely appears
  /// twice in a row.
  void _loadNextPuzzle() {
    final tier = DifficultyCurve.tierForScore(totalMarks);
    final type = _pickNextType();
    _currentPuzzle = PuzzleGenerator.generate(tier: tier, type: type, rng: _rng);
    notifyListeners();
  }

  PuzzleType _pickNextType() {
    final values = PuzzleType.values;
    var type = values[_rng.nextInt(0, values.length - 1)];
    if (_currentPuzzle != null && type == _currentPuzzle!.type) {
      // One reroll only — still fine if it happens to match again, this
      // is a mild variety nudge, not a hard constraint.
      type = values[_rng.nextInt(0, values.length - 1)];
    }
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
