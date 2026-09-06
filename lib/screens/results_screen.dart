import 'package:flutter/material.dart';

import '../models/test_session.dart';
import '../utils/constants.dart';

/// The end-of-test screen: final marks, a correct/wrong/skipped
/// breakdown, a "new high score" banner if earned, and Play Again / Home.
///
/// Takes an [onPlayAgain] callback rather than importing `game_screen.dart`
/// directly — keeps this screen reusable/testable on its own and avoids a
/// circular import (game_screen navigates *to* this screen).
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.testSession,
    required this.previousHighScore,
    required this.onPlayAgain,
  });

  final TestSession testSession;
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
    final isNewHighScore = testSession.totalMarks > previousHighScore;
    final bestScore =
        isNewHighScore ? testSession.totalMarks : previousHighScore;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Test Complete')),
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
                '${testSession.totalMarks}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('total marks'),
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
                  child: const Text('Play Again'),
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
