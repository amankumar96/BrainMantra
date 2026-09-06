import 'package:flutter/material.dart';

import '../models/player_stats.dart';
import '../services/ads_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/rules_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStats();
    _maybeShowRulesForTheFirstTime();
  }

  Future<void> _loadStats() async {
    final stats = await StorageService.loadStats();
    if (mounted) setState(() => _stats = stats);
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

  @override
  Widget build(BuildContext context) {
    final stats = _stats ?? PlayerStats();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MathBlitz'),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'High Score: ${stats.highScore}',
                style: const TextStyle(
                  fontSize: AppText.score,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Streak: ${stats.currentStreakDays} days'),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToGame(isDailyChallenge: false),
                  child: const Text('Play'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _navigateToGame(isDailyChallenge: true),
                  child: const Text('Daily Challenge'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _navigateToLeaderboard,
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('Leaderboard'),
                ),
              ),
            ],
          ),
        ),
      ),
      // Banner ads are confined to Home only — never gameplay's countdown
      // or results' Play-Again/Home decision (see ARCHITECTURE.md's
      // Phase 4 write-up). bottomNavigationBar keeps it pinned outside
      // the centered Column above, so it never disturbs that layout.
      bottomNavigationBar: AdsService.instance.bannerAdWidget(),
    );
  }
}
