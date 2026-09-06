import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// A plain readout of test progress and running score — replaces the
/// original combo/lives design now that scoring is a marks tally
/// (+4/-2/0) rather than a survival game with lives.
/// Purely a projection of numbers the caller already has; holds no state.
class MarksIndicator extends StatelessWidget {
  const MarksIndicator({
    super.key,
    required this.currentQuestionNumber, // 1-based, e.g. 4 of 10
    required this.totalQuestions, // null = no fixed total (Play mode)
    required this.marksSoFar,
  });

  final int currentQuestionNumber;
  final int? totalQuestions;
  final int marksSoFar;

  @override
  Widget build(BuildContext context) {
    // Explicit '+' for positive totals so it reads as a signed tally
    // (e.g. "+12 marks") rather than being mistaken for a plain count.
    final sign = marksSoFar > 0 ? '+' : '';
    final progressText = totalQuestions == null
        ? 'Question $currentQuestionNumber'
        : 'Question $currentQuestionNumber of $totalQuestions';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          progressText,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          '$sign$marksSoFar marks',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppText.score,
          ),
        ),
      ],
    );
  }
}
