import 'package:flutter/material.dart';

import '../models/player_stats.dart';
import '../services/ads_service.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/rules_dialog.dart';
import 'delete_account_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

/// The title screen: high score, streak, an on-demand rules icon (item 6
/// of the product requirements), and the two ways to start a test.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Null while StorageService.loadStats() is still resolving. Using
  // PlayerStats()'s own 0/0 defaults for that brief window (rather than a
  // loading spinner) is what makes a fresh install "show 0/0 gracefully"
  // instead of an empty or crashing screen.
  PlayerStats? _stats;

  // Best-effort greeting name — never blocks Home's first paint. Reuses
  // the same profile lookup `leaderboard_screen.dart` already uses to
  // show "You (name)"; a 'Player' fallback covers a fresh
  // profile/offline/slow network/any failure, same "best-effort, never
  // load-bearing" precedent every other Supabase call in this app
  // follows (see game_screen.dart's _persistAndShowResults).
  String _displayName = 'Player';

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDisplayName();
    _maybeShowRulesForTheFirstTime();
  }

  Future<void> _loadStats() async {
    final stats = await StorageService.loadStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _loadDisplayName() async {
    try {
      final result = await LeaderboardService.fetchMyEntryAndRank();
      if (mounted && result != null) {
        setState(() => _displayName = result.entry.displayName);
      }
    } catch (_) {
      // Keep the 'Player' fallback — never break Home over this.
    }
  }

  /// Shows the rules dialog automatically exactly once — the first time a
  /// player ever reaches this screen, regardless of whether they arrived
  /// via email sign-up or Google sign-in. Deferred to after the first
  /// frame since showDialog needs a fully-mounted Navigator/Overlay.
  Future<void> _maybeShowRulesForTheFirstTime() async {
    final alreadySeen = await StorageService.hasSeenRules();
    if (alreadySeen || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await RulesDialog.show(context);
      await StorageService.markRulesSeen();
    });
  }

  Future<void> _navigateToGame({required bool isDailyChallenge}) async {
    // Play resumes from the player's persisted score; Daily Challenge
    // always starts fresh at 0, per its fairness rules.
    final startingScore =
        isDailyChallenge ? 0 : await AuthService.fetchCurrentScore();
    if (!mounted) return;

    // Reload stats once this pushed route is replaced (GameScreen
    // replaces itself with ResultsScreen when the session ends, which
    // resolves this push's Future) — by then StorageService.saveStats
    // has already run, so the refreshed high score/streak are ready the
    // next time this screen is actually visible again.
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        isDailyChallenge: isDailyChallenge,
        startingScore: startingScore,
      ),
    ));
    _loadStats();
  }

  void _navigateToLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  void _navigateToDeleteAccount() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats ?? PlayerStats();
    return Scaffold(
      backgroundColor: Colors.white,
      // No standard AppBar — the header below is a custom gradient block
      // that the scrollable white "sheet" purposely overlaps (see the
      // Transform.translate below), matching a supplied mockup's layered
      // look.
      body: Column(
        children: [
          _HomeHeader(
            onRulesTap: () => RulesDialog.show(context),
            onSignOutTap: () => AuthService.signOut(),
          ),
          Expanded(
            // Transform (not a negative Container margin, which Flutter
            // rejects with an assertion) is what lets this "sheet"
            // visually overlap the header's bottom edge — it shifts
            // painting only, so the Expanded box's true layout bottom
            // stays put; the resulting sliver of unpainted space at the
            // very bottom shows through as the Scaffold's own white
            // background, matching this sheet's color exactly.
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GreetingAndMarksRow(
                          displayName: _displayName,
                          streakDays: stats.currentStreakDays,
                          marks: stats.highScore,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _HeroCard(
                          onPlay: () =>
                              _navigateToGame(isDailyChallenge: false),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _DailyChallengeBox(
                          onTap: () =>
                              _navigateToGame(isDailyChallenge: true),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LeaderboardBox(onTap: _navigateToLeaderboard),
                        const SizedBox(height: AppSpacing.md),
                        // Banner ads are confined to Home only — never
                        // gameplay's countdown or results' Play-Again/Home
                        // decision (see ARCHITECTURE.md's Phase 4
                        // write-up).
                        AdsService.instance.bannerAdWidget(showPlaceholder: true),
                        const SizedBox(height: AppSpacing.md),
                        _DeleteAccountBox(onTap: _navigateToDeleteAccount),
                        const SizedBox(height: AppSpacing.lg),
                        const _Footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gradient top block — brain mark + app name/tagline on the left,
/// the Rules/Sign-out icons on the right. Replaces the plain `AppBar`;
/// its bottom edge is deliberately overlapped by the scrollable white
/// sheet below it (see `HomeScreen.build`'s `Transform.translate`) for
/// the "card sitting on the header" look.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onRulesTap, required this.onSignOutTap});

  final VoidCallback onRulesTap;
  final VoidCallback onSignOutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
        ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Brain Mantra',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Train Today, Brighter Tomorrow',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Rules',
            onPressed: onRulesTap,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign out',
            onPressed: onSignOutTap,
          ),
        ],
      ),
    );
  }
}

/// Two-line greeting ("Hey **{name}** 👋" / "Welcome back! Your day
/// streak is **{N}** 🔥") next to a highlighted marks pill. Each line is
/// its own `Text.rich`/`TextSpan` (not several separate `Text` widgets)
/// so it reads and wraps as one sentence, with the name/streak bolded
/// and colored.
class _GreetingAndMarksRow extends StatelessWidget {
  const _GreetingAndMarksRow({
    required this.displayName,
    required this.streakDays,
    required this.marks,
  });

  final String displayName;
  final int streakDays;
  final int marks;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 17, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'Hey '),
                    TextSpan(
                      text: displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: ' 👋'),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  children: [
                    const TextSpan(text: 'Welcome back! Your day streak is '),
                    TextSpan(
                      text: '$streakDays',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: ' 🔥'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.headerGradientStart,
                AppColors.headerGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 16, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$marks',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppText.score,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The main hero card: gradient background, the brain mascot, a
/// "Challenge your skills" headline, and the PLAY button — the app's
/// central visual identity moment on Home.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Challenge\nyour skills',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sharpen your mind with fun questions every day!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Image.asset('assets/icons/icon.png'),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: onPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.heroGradientEnd,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text(
                    'PLAY',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Small Steps\nBig Progress!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pastel-tinted row shared by Daily Challenge and Leaderboard: a
/// circular icon badge, a title/subtitle column, and a trailing chevron
/// badge — all sharing one [accent] color per row.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.onTap,
    required this.backgroundColor,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Icon(Icons.chevron_right, color: accent, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyChallengeBox extends StatelessWidget {
  const _DailyChallengeBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MenuRow(
      onTap: onTap,
      backgroundColor: AppColors.dailyChallengeCard,
      accent: AppColors.dailyChallengeAccent,
      icon: Icons.event_available_rounded,
      title: 'Daily Challenge',
      subtitle: 'Earn extra Marks solving these Questions',
    );
  }
}

/// Replaces the old plain `TextButton.icon` link with a styled row
/// matching Daily Challenge's visual language.
class _LeaderboardBox extends StatelessWidget {
  const _LeaderboardBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MenuRow(
      onTap: onTap,
      backgroundColor: AppColors.leaderboardCard,
      accent: AppColors.leaderboardAccent,
      icon: Icons.bar_chart_rounded,
      title: 'Leaderboard',
      subtitle: 'See how you rank among sharp minds!',
    );
  }
}

/// A full-width, red destructive-action box — a normal flow item at the
/// very end of the page (not corner-pinned).
class _DeleteAccountBox extends StatelessWidget {
  const _DeleteAccountBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.wrong,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: const Icon(Icons.delete_outline),
      label: const Text(
        'Delete Account',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// The small centered tagline at the very bottom of the page, flanked by
/// thin divider lines.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.silver)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'A Sharper You, A Brighter Tomorrow',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.silver)),
      ],
    );
  }
}
