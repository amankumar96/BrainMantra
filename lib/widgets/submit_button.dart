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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasSelection ? onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: Colors.black12,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
        child: const Text('Submit'),
      ),
    );
  }
}
