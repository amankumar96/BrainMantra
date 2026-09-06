import 'package:flutter/material.dart';

import '../models/test_session.dart';
import '../utils/constants.dart';

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
  });

  final TestSession testSession;

  /// The headline number to show — deliberately **not**
  /// `testSession.totalMarks` (which is only this session's delta): for
  /// Play mode, this is the player's cumulative persisted score
  /// (`GameController.totalMarks`, i.e. "score till now"), so ending a
  /// session shows the real running total, not just what was earned in
  /// this one sitting. For Daily Challenge, which always starts at 0,
  /// this happens to equal `testSession.totalMarks` anyway.
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isDailyChallenge ? 'Test Complete' : 'Session Ended'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              Text(isDailyChallenge ? 'total marks' : 'score so far'),
              const SizedBox(height: AppSpacing.lg),
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
              Text('Best score: $bestScore'),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  child: Text(isDailyChallenge ? 'Play Again' : 'Continue Playing'),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Home'),
              ),
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
