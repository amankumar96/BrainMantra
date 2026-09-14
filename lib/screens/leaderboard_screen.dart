import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/leaderboard_service.dart';
import '../utils/constants.dart';

/// Shows everyone ranked by their persistent total score (Play + Daily
/// Challenge combined — see `LeaderboardService`'s own doc comment) among
/// players active in the last 30 days: the signed-in player's own global
/// rank in a card at the top, then the top 10 below it.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// Everything this screen's `FutureBuilder` needs, fetched together so
/// there's one loading/error state to render rather than juggling two
/// independent futures.
class _LeaderboardData {
  const _LeaderboardData({required this.topTen, required this.myEntryAndRank});

  final List<LeaderboardEntry> topTen;
  final ({LeaderboardEntry entry, int rank})? myEntryAndRank;
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<_LeaderboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_LeaderboardData> _load() async {
    final results = await Future.wait([
      LeaderboardService.fetchTopRankings(limit: 10),
      LeaderboardService.fetchMyEntryAndRank(),
    ]);
    return _LeaderboardData(
      topTen: results[0] as List<LeaderboardEntry>,
      myEntryAndRank: results[1] as ({LeaderboardEntry entry, int rank})?,
    );
  }

  /// `Supabase.instance` asserts (throws) if `Supabase.initialize()` was
  /// never called — true in every widget test, since none of them spin up
  /// a real/mocked Supabase client. This is only ever used to highlight
  /// the current user's own row, a nicety, not load-bearing — defensive
  /// here the same way this codebase treats every other optional read
  /// that shouldn't be able to crash the screen around it.
  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Leaderboard — Last 30 Days')),
      body: FutureBuilder<_LeaderboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Could not load the leaderboard: ${snapshot.error}'),
              ),
            );
          }
          final data = snapshot.data!;
          if (data.topTen.isEmpty) {
            return const Center(
              child: Text('No players active in the last 30 days yet.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (data.myEntryAndRank != null) ...[
                _MyRankCard(
                  rank: data.myEntryAndRank!.rank,
                  entry: data.myEntryAndRank!.entry,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Text(
                'Top Rankers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < data.topTen.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _LeaderboardRow(
                    rank: i + 1,
                    entry: data.topTen[i],
                    isCurrentUser: data.topTen[i].userId == currentUserId,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The signed-in player's own rank, pinned above the top-10 list — a
/// light-green box holding a square rank badge and a rectangle with the
/// player's name and score, matching the top-10 rows' shape but styled
/// distinctly (green, slightly larger) so it reads as "you," not just
/// another list entry.
class _MyRankCard extends StatelessWidget {
  const _MyRankCard({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF5E6), // light green
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF43A047), width: 2),
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank, background: const Color(0xFF43A047)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'You (${entry.displayName})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${entry.totalScore} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the top-10 list: a square rank badge (Box [rank]) next to a
/// rectangle holding the player's name and score, per the requested
/// `Box [rank] rectangle [name —— score]` layout.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RankBadge(
          rank: rank,
          background: isCurrentUser ? AppColors.primary : AppColors.silver,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.silver),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.displayName,
                  style: TextStyle(
                    fontWeight:
                        isCurrentUser ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${entry.totalScore} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The square "Box [rank]" badge shared by [_MyRankCard] and
/// [_LeaderboardRow].
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.background});

  final int rank;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
