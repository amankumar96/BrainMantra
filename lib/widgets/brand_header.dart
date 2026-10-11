import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_language.dart';
import '../services/language_controller.dart';
import '../utils/constants.dart';
import 'header_wave_painter.dart';

/// The gradient top banner used on both [HomeScreen] and the auth
/// screens (Login/Sign up): brain-and-wand icon + app name/tagline on the
/// left, an optional row of trailing icon buttons on the right (Home's
/// Rules/Sign-out; the auth screens pass none). Pulling this out of
/// `home_screen.dart` is what lets Login/Sign-up carry the exact same
/// banner rather than a hand-copied lookalike that could drift out of
/// sync with it over time.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.tagline,
    this.actions = const [],
  });

  /// Defaults per-language (see `build()`) when left null — only
  /// `sign_up_screen.dart` (currently unreachable; email/password sign-in
  /// is disabled) overrides this with its own fixed English copy.
  final String? tagline;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageController>().language;
    final resolvedTagline = tagline ??
        (language == AppLanguage.english
            ? 'Boost Your Brainpower Daily'
            : 'हर दिन अपने दिमाग को तेज़ करें');
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
        ),
      ),
      // A Stack so the wave decoration paints behind the actual header
      // content, never disturbing that content's own layout.
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: HeaderWavePainter()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              MediaQuery.paddingOf(context).top + AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Brain Mantra',
                        // Explicit single-line guard — without this, a
                        // real bug: adding the 3rd action icon
                        // (Settings) narrowed this Expanded column
                        // enough that "Brain Mantra" sometimes wrapped
                        // onto 2 lines ("Brain" / "Mantra") instead of
                        // shrinking via ellipsis like the tagline below
                        // it already does.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      // A short, plainly descriptive line — deliberately
                      // not a slogan/tagline that could resemble anyone
                      // else's copyrighted wording. Single line always:
                      // smaller font + maxLines/overflow guard rather than
                      // a wrapped second line.
                      Text(
                        resolvedTagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
