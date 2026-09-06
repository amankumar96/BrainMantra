import 'package:flutter/material.dart';

import '../models/player_stats.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/rules_dialog.dart';
import 'game_screen.dart';

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
  }

  Future<void> _loadStats() async {
    final stats = await StorageService.loadStats();
    if (mounted) setState(() => _stats = stats);
  }

  void _navigateToGame({required bool isDailyChallenge}) {
    // Reload stats once this pushed route is replaced (GameScreen
    // replaces itself with ResultsScreen when the test ends, which
    // resolves this push's Future) — by then StorageService.saveStats
    // has already run, so the refreshed high score/streak are ready the
    // next time this screen is actually visible again.
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => GameScreen(isDailyChallenge: isDailyChallenge),
        ))
        .then((_) => _loadStats());
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
            ],
          ),
        ),
      ),
    );
  }
}
