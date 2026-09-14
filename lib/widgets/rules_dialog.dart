import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// The game rules, shown automatically once right after a new player
/// signs up, and reachable anytime afterward via an info icon on the
/// home screen (item 6 of the product requirements) — both call sites
/// use this same widget so the wording never drifts out of sync.
class RulesDialog extends StatelessWidget {
  const RulesDialog({super.key});

  /// Opens the dialog and waits for the player to dismiss it.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const RulesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How Brain Mantra Works'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _RuleItem(
              icon: Icons.check_circle_outline,
              text: 'Play: +4 marks for a correct answer, -2 for a wrong '
                  'one.',
            ),
            _RuleItem(
              icon: Icons.timer_off_outlined,
              text: 'Time runs out before you answer: 0 marks — '
                  'no penalty for skipping, in either mode.',
            ),
            _RuleItem(
              icon: Icons.touch_app_outlined,
              text: 'Only 1 attempt per question: pick an option, then '
                  'press Submit to lock it in. You can change your pick '
                  'until you press Submit.',
            ),
            _RuleItem(
              icon: Icons.hourglass_bottom_outlined,
              text: 'Each question has a time limit between 2 and 30 '
                  'minutes, depending on its difficulty.',
            ),
            _RuleItem(
              icon: Icons.calendar_month_outlined,
              text: 'Daily Challenge: tougher questions only (tier 3+), '
                  '+10 marks for a correct answer, 0 for a wrong one — no '
                  'deduction. What you earn is added straight onto your '
                  'regular Play score.',
            ),
            _RuleItem(
              icon: Icons.leaderboard_outlined,
              text: 'Daily Challenge results also count toward the '
                  'leaderboard, ranked among players active in the last '
                  '30 days.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('I understand'),
        ),
      ],
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
