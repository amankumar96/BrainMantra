import 'package:flutter/material.dart';

import '../models/age_group.dart';
import '../models/test_session.dart';
import '../utils/constants.dart';

/// Age-Group Tests pass at 12/30 (40%) correct — TUNABLE, matches the
/// feature plan's explicit pass-threshold decision.
const double ageGroupTestPassFraction = 0.4;

/// The end-of-session screen: current score, a correct/wrong/skipped
/// breakdown of *this* session, a "new high score" banner if earned, and
/// Play Again / Home.
///
/// Takes an [onPlayAgain] callback rather than importing `game_screen.dart`
/// directly — keeps this screen reusable/testable on its own and avoids a
/// circular import (game_screen navigates *to* this screen).
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.testSession,
    required this.currentScore,
    required this.previousHighScore,
    required this.onPlayAgain,
    this.ageGroupTest,
  });

  final TestSession testSession;

  /// Non-null only for an Age-Group Test (`game_screen.dart`'s
  /// `ageGroupTest` param) — switches this whole screen to the pass/fail
  /// presentation (no score shown, no leaderboard effect) instead of the
  /// normal score-centric one, per the feature plan.
  final AgeGroup? ageGroupTest;

  /// The headline number to show — deliberately **not**
  /// `testSession.totalMarks` (which is only this session's delta). This
  /// is always the player's cumulative persisted score: for Play mode
  /// it's `GameController.totalMarks` ("score till now"); for Daily
  /// Challenge it's that same persistent total *plus* what this
  /// challenge just earned — Daily Challenge no longer keeps an isolated
  /// score of its own, its marks are a bonus on top of the one running
  /// total (see `game_screen.dart`'s `_persistAndShowResults`).
  final int currentScore;
  final int previousHighScore;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final correctCount =
        testSession.outcomes.where((o) => o == AnswerOutcome.correct).length;
    final wrongCount =
        testSession.outcomes.where((o) => o == AnswerOutcome.wrong).length;
    final skippedCount =
        testSession.outcomes.where((o) => o == AnswerOutcome.skipped).length;
    final isNewHighScore = currentScore > previousHighScore;
    final bestScore = isNewHighScore ? currentScore : previousHighScore;
    final isDailyChallenge = testSession.session.isDailyChallenge;
    final isAgeGroupTest = ageGroupTest != null;
    final totalAnswered = testSession.outcomes.length;
    final passed = isAgeGroupTest &&
        totalAnswered > 0 &&
        correctCount / totalAnswered >= ageGroupTestPassFraction;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isAgeGroupTest
              ? '${ageGroupTest!.label} Test Result'
              : (isDailyChallenge ? 'Test Complete' : 'Session Ended'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Age-Group Tests show no score or leaderboard effect at
              // all — only a pass/fail verdict, per the feature plan.
              if (isAgeGroupTest) ...[
                Icon(
                  passed ? Icons.check_circle : Icons.refresh,
                  size: 48,
                  color: passed ? AppColors.correct : AppColors.neutral,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  passed ? 'Congratulations! You passed' : 'Try again next time',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else ...[
                if (isNewHighScore) ...[
                  const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'NEW HIGH SCORE!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  '$currentScore',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('score so far'),
                if (isDailyChallenge) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '+${testSession.totalMarks} from today\'s Daily Challenge',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              _StatRow(
                label: 'Correct',
                value: correctCount,
                color: AppColors.correct,
              ),
              _StatRow(
                label: 'Wrong',
                value: wrongCount,
                color: AppColors.wrong,
              ),
              _StatRow(
                label: 'Skipped',
                value: skippedCount,
                color: AppColors.neutral,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!isAgeGroupTest) ...[
                Text('Best score: $bestScore'),
                const SizedBox(height: AppSpacing.lg),
              ],
              // An Age-Group Test is on a 2-hour cooldown, so there's no
              // immediate "Try Again" here — bypassing it with a direct
              // retry button would defeat the cooldown entirely. Only Home
              // is offered; the next attempt starts from there, once due.
              if (isAgeGroupTest)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Text('Back to Home'),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    child: Text(
                      isDailyChallenge ? 'Play Again' : 'Continue Playing',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$label: $value'),
        ],
      ),
    );
  }
}
