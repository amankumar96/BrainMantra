import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_language.dart';
import '../services/language_controller.dart';
import '../utils/constants.dart';

/// Reachable from Home's header (alongside the existing Rules/Sign-out
/// icons) — lets a player change their language choice anytime after
/// the login screen's first-run pick, without needing to sign out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LanguageController>();
    final language = controller.language;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_t(language, 'Settings', 'सेटिंग्स')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(language, 'Language', 'भाषा'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final option in AppLanguage.values) ...[
                _LanguageOption(
                  language: option,
                  selected: language == option,
                  onTap: () => controller.setLanguage(option),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.neutral,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                language.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppColors.primary : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks [en] or [hi] depending on [language].
String _t(AppLanguage language, String en, String hi) =>
    language == AppLanguage.english ? en : hi;
