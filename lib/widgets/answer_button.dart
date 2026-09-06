import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// The visual state one [AnswerButton] can be in. `game_screen` decides
/// which state each button is in — this widget just renders whatever
/// it's told, it holds no game logic itself.
enum AnswerButtonState {
  /// Not yet picked, nothing submitted yet — plain, tappable.
  normal,

  /// Picked (via [AnswerButton.onTap]) but not yet submitted — the player
  /// can still tap a different option to change their mind.
  selected,

  /// Submitted and correct — shown after Submit is pressed.
  correct,

  /// Submitted and wrong — shown after Submit is pressed. Also used to
  /// mark the tapped-but-wrong option, while the *actually* correct
  /// option elsewhere on screen is separately shown as [correct].
  wrong,

  /// Not tappable — either an answer was already submitted for this
  /// question, or the question timed out.
  disabled,
}

/// One tappable multiple-choice option. Used for every puzzle type (2
/// options for true/false, 4 for everything else) — purely presentational.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.label,
    required this.onTap,
    this.state = AnswerButtonState.normal,
  });

  final String label;

  /// Called when tapped. Pass null (rather than relying solely on
  /// [state]) to make a button non-interactive — e.g. once an answer has
  /// been submitted for the current question.
  final VoidCallback? onTap;
  final AnswerButtonState state;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, borderColor) = _colorsFor(state);
    // Never respond to taps while disabled, even if a caller accidentally
    // still passes a non-null onTap — this widget owns its own
    // interactivity rule for that one state.
    final effectiveOnTap = state == AnswerButtonState.disabled ? null : onTap;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: AppText.score,
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a state to (background, text, border) colors. Kept as one small
  /// pure function so the color scheme can be adjusted in a single place.
  (Color, Color, Color) _colorsFor(AnswerButtonState state) => switch (state) {
        AnswerButtonState.normal => (
            Colors.white,
            Colors.black87,
            Colors.black26,
          ),
        AnswerButtonState.selected => (
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary,
            AppColors.primary,
          ),
        AnswerButtonState.correct => (
            AppColors.correct.withValues(alpha: 0.15),
            AppColors.correct,
            AppColors.correct,
          ),
        AnswerButtonState.wrong => (
            AppColors.wrong.withValues(alpha: 0.15),
            AppColors.wrong,
            AppColors.wrong,
          ),
        AnswerButtonState.disabled => (
            Colors.white,
            Colors.black38,
            Colors.black12,
          ),
      };
}
