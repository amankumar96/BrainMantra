import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_language.dart';
import '../services/language_controller.dart';
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
    final language = context.watch<LanguageController>().language;
    final isHindi = language == AppLanguage.hindi;
    return AlertDialog(
      title: Text(
        isHindi ? 'ब्रेन मंत्र कैसे काम करता है' : 'How Brain Mantra Works',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _RuleItem(
              icon: Icons.check_circle_outline,
              text: isHindi
                  ? 'खेलें: सही उत्तर के लिए +4 मार्क्स, गलत के लिए -2।'
                  : 'Play: +4 marks for a correct answer, -2 for a wrong '
                      'one.',
            ),
            _RuleItem(
              icon: Icons.timer_off_outlined,
              text: isHindi
                  ? 'जवाब देने से पहले समय समाप्त हो जाए: 0 मार्क्स — '
                      'दोनों मोड में छोड़ने पर कोई जुर्माना नहीं।'
                  : 'Time runs out before you answer: 0 marks — '
                      'no penalty for skipping, in either mode.',
            ),
            _RuleItem(
              icon: Icons.touch_app_outlined,
              text: isHindi
                  ? 'हर सवाल के लिए सिर्फ 1 मौका: एक विकल्प चुनें, फिर उसे '
                      'पक्का करने के लिए जमा करें दबाएं। जमा करें दबाने तक '
                      'आप अपनी पसंद बदल सकते हैं।'
                  : 'Only 1 attempt per question: pick an option, then '
                      'press Submit to lock it in. You can change your pick '
                      'until you press Submit.',
            ),
            _RuleItem(
              icon: Icons.hourglass_bottom_outlined,
              text: isHindi
                  ? 'हर सवाल की कठिनाई के अनुसार 2 से 30 मिनट के बीच समय '
                      'सीमा होती है।'
                  : 'Each question has a time limit between 2 and 30 '
                      'minutes, depending on its difficulty.',
            ),
            _RuleItem(
              icon: Icons.calendar_month_outlined,
              text: isHindi
                  ? 'दैनिक चुनौती: केवल कठिन सवाल (टियर 3+), सही उत्तर के '
                      'लिए +10 मार्क्स, गलत के लिए 0 — कोई कटौती नहीं। '
                      'आपकी कमाई सीधे आपके सामान्य प्ले स्कोर में जोड़ी '
                      'जाती है।'
                  : 'Daily Challenge: tougher questions only (tier 3+), '
                      '+10 marks for a correct answer, 0 for a wrong one — no '
                      'deduction. What you earn is added straight onto your '
                      'regular Play score.',
            ),
            _RuleItem(
              icon: Icons.leaderboard_outlined,
              text: isHindi
                  ? 'दैनिक चुनौती के नतीजे लीडरबोर्ड में भी गिने जाते हैं, '
                      'पिछले 30 दिनों में सक्रिय खिलाड़ियों के बीच रैंक '
                      'किए जाते हैं।'
                  : 'Daily Challenge results also count toward the '
                      'leaderboard, ranked among players active in the last '
                      '30 days.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isHindi ? 'मैं समझ गया' : 'I understand'),
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
