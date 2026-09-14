import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// The explicit "lock in my answer" button the two-step answer flow needs:
/// tapping an [AnswerButton] only *selects* an option, this button is what
/// actually submits it. Stays disabled until something is selected, which
/// is what makes "only 1 attempt before Submit" a real UI constraint
/// rather than just a rule written down somewhere.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.hasSelection,
    required this.onSubmit,
  });

  /// Whether the player has picked an option yet. When false, the button
  /// renders visibly greyed-out and ignores taps.
  final bool hasSelection;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // A light fill (not a solid-indigo one) so an explicitly *dark*
    // foreground is unambiguously legible against it, rather than relying
    // on Material's seed-derived `onPrimary` against a dark button (the
    // contrast bug this specific styling fixes) — the indigo border keeps
    // it visually tied to the brand's primary color without needing the
    // text to sit on top of it.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasSelection ? onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.submitButtonText,
          disabledBackgroundColor: Colors.black12,
          disabledForegroundColor: Colors.black38,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        child: const Text('Submit'),
      ),
    );
  }
}
