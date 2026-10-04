import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/age_group.dart';
import '../models/app_language.dart';
import '../models/test_session.dart';
import '../services/language_controller.dart';
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
    final language = context.watch<LanguageController>().language;
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
              ? '${ageGroupTest!.label} ${_t(language, 'Test Result', 'टेस्ट परिणाम')}'
              : (isDailyChallenge
                  ? _t(language, 'Test Complete', 'टेस्ट पूरा हुआ')
                  : _t(language, 'Session Ended', 'सत्र समाप्त हुआ')),
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
                  passed
                      ? _t(language, 'Congratulations! You passed',
                          'बधाई हो! आप पास हो गए')
                      : _t(language, 'Try again next time',
                          'अगली बार फिर कोशिश करें'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else ...[
                if (isNewHighScore) ...[
                  const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _t(language, 'NEW HIGH SCORE!', 'नया हाई स्कोर!'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                Text(_t(language, 'score so far', 'अब तक का स्कोर')),
                if (isDailyChallenge) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _t(
                      language,
                      "+${testSession.totalMarks} from today's Daily Challenge",
                      '+${testSession.totalMarks} आज की दैनिक चुनौती से',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              _StatRow(
                label: _t(language, 'Correct', 'सही'),
                value: correctCount,
                color: AppColors.correct,
              ),
              _StatRow(
                label: _t(language, 'Wrong', 'गलत'),
                value: wrongCount,
                color: AppColors.wrong,
              ),
              _StatRow(
                label: _t(language, 'Skipped', 'छोड़ी गई'),
                value: skippedCount,
                color: AppColors.neutral,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!isAgeGroupTest) ...[
                Text(_t(language, 'Best score: $bestScore', 'सर्वश्रेष्ठ स्कोर: $bestScore')),
                const SizedBox(height: AppSpacing.lg),
              ],
              // By explicit product decision there's no cooldown on an
              // Age-Group Test anymore (see home_screen.dart) — only Home
              // is offered here anyway, simply because this screen never
              // had a "retry this exact Test" callback wired to it (unlike
              // Play/Daily Challenge's onPlayAgain); a player who wants
              // another attempt just taps the card again from Home.
              if (isAgeGroupTest)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: Text(_t(language, 'Back to Home', 'होम पर वापस जाएं')),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    child: Text(
                      isDailyChallenge
                          ? _t(language, 'Play Again', 'फिर से खेलें')
                          : _t(language, 'Continue Playing', 'खेलना जारी रखें'),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(_t(language, 'Home', 'होम')),
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

/// Picks [en] or [hi] depending on [language].
String _t(AppLanguage language, String en, String hi) =>
    language == AppLanguage.english ? en : hi;
