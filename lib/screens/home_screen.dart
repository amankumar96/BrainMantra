import 'package:flutter/material.dart';

import '../models/player_stats.dart';
import '../services/ads_service.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/floating_numbers_background.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Brain Mantra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Rules',
            onPressed: () => RulesDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService.signOut(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // First child — paints behind everything else, so it never
          // disturbs the scrollable content above it.
          const Positioned.fill(child: FloatingNumbersBackground()),
          SafeArea(
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
                  const _LogoHeroBox(),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => _navigateToGame(isDailyChallenge: false),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    child: const Text(
                      'PLAY',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DailyChallengeBox(
                    onTap: () => _navigateToGame(isDailyChallenge: true),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _LeaderboardBox(onTap: _navigateToLeaderboard),
                  const SizedBox(height: AppSpacing.md),
                  // Banner ads are confined to Home only — never
                  // gameplay's countdown or results' Play-Again/Home
                  // decision (see ARCHITECTURE.md's Phase 4 write-up).
                  // Now a normal flow item (was Scaffold.bottomNavigationBar)
                  // so it sits in this specific position, per spec.
                  AdsService.instance.bannerAdWidget(),
                  const SizedBox(height: AppSpacing.md),
                  _DeleteAccountBox(onTap: _navigateToDeleteAccount),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single `Text.rich` — "Hey {name}, welcome to your day streak of
/// {N}" with the name and streak number bolded, everything else regular
/// weight — next to a highlighted marks pill. `Text.rich`/`TextSpan`
/// (not several separate `Text` widgets) so the whole greeting reads and
/// wraps as one sentence.
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
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              children: [
                const TextSpan(text: 'Hey '),
                TextSpan(
                  text: displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ', welcome to your day streak of '),
                TextSpan(
                  text: '$streakDays',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
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

/// The app logo, framed in a "neon blue" hero box with a small tagline —
/// the app's own visual identity moment above the Play button.
class _LogoHeroBox extends StatelessWidget {
  const _LogoHeroBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.neonBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Image.asset('assets/icons/icon.png', width: 120, height: 120),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Challenge your skills',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded box promoting Daily Challenge — same navigation as before,
/// now with a tagline explaining the extra reward.
class _DailyChallengeBox extends StatelessWidget {
  const _DailyChallengeBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.silver),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Challenge',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Earn extra Marks solving these Questions',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded box linking to the Leaderboard — replaces the old plain
/// `TextButton.icon` link with a styled box matching the other Home
/// sections, reusing `leaderboard_screen.dart`'s rounded-box/silver-border
/// visual language.
class _LeaderboardBox extends StatelessWidget {
  const _LeaderboardBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.silver),
          ),
          child: const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Leaderboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width, red destructive-action box — replaces the old small
/// corner-pinned link with a normal flow item at the very end of the
/// page, same navigation as before.
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
