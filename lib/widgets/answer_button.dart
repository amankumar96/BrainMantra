import 'package:flutter/material.dart';

import '../models/diagram_data.dart';
import '../utils/constants.dart';
import 'diagram_painter.dart';

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
          // Tighter than the original AppSpacing.md on every side —
          // together with AppText.answerOption's smaller font, this is
          // what keeps a full question + 4 options fitting on one phone
          // screen without scrolling.
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
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
              fontSize: AppText.answerOption,
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _colorsFor(AnswerButtonState state) =>
      colorsForAnswerState(state);
}

/// Maps a state to (background, foreground, border) colors — shared by
/// [AnswerButton] (text options) and [DiagramAnswerButton] (rendered-shape
/// options) so both option styles read as the same visual family, kept as
/// one small pure function so the color scheme can be adjusted in a single
/// place.
(Color, Color, Color) colorsForAnswerState(AnswerButtonState state) =>
    switch (state) {
      AnswerButtonState.normal => (
          Colors.white,
          Colors.black87,
          AppColors.silver,
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

/// A multiple-choice option rendered as a small diagram instead of text —
/// used when `Puzzle.optionDiagrams` is set (Phase 13: mirror/water image
/// puzzles, where the 4 "answers" are themselves shapes to pick between).
/// Deliberately square and fixed-size (always wrapped in an `AspectRatio`
/// by its caller) with a hard `ClipRect` backstop, so all 4 options in a
/// grid line up as one uniform, regular block — a shape can never make its
/// own option box a different size or spill past its border, regardless
/// of the shape's own aspect ratio. Shares [AnswerButton]'s exact color
/// states via [colorsForAnswerState] so the two option styles never look
/// like they belong to different apps.
class DiagramAnswerButton extends StatelessWidget {
  const DiagramAnswerButton({
    super.key,
    required this.diagram,
    required this.onTap,
    this.state = AnswerButtonState.normal,
  });

  final DiagramData diagram;
  final VoidCallback? onTap;
  final AnswerButtonState state;

  @override
  Widget build(BuildContext context) {
    final (background, _, borderColor) = colorsForAnswerState(state);
    final effectiveOnTap = state == AnswerButtonState.disabled ? null : onTap;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(color: borderColor, width: 2),
          ),
          // ClipRect is the hard backstop — DiagramPainter's own
          // polygonPoints already fits any shape to the box it's given
          // (see its doc comment), but this guarantees nothing can ever
          // visually escape this option's bounds regardless of a future
          // edge case in the painter, the same belt-and-braces pattern
          // game_screen.dart's question-diagram frame already uses.
          child: ClipRect(
            child: CustomPaint(painter: DiagramPainter(diagram)),
          ),
        ),
      ),
    );
  }
}
