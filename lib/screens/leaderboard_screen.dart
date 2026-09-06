import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/leaderboard_service.dart';
import '../utils/constants.dart';

/// Shows everyone ranked by total Daily Challenge marks in the last 30
/// days (the `leaderboard_last_30_days` Supabase view already does the
/// filtering/sorting — this screen just displays what it returns).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _rankingsFuture;

  @override
  void initState() {
    super.initState();
    _rankingsFuture = LeaderboardService.fetchTopRankings();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Leaderboard — Last 30 Days')),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _rankingsFuture,
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
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return const Center(
              child: Text('No Daily Challenge results yet in the last 30 days.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            // +1 for the participant-count header row.
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                // entries is capped at fetchTopRankings' limit (50) — this
                // count is exact only up to that cap, "50+" beyond it.
                final label = entries.length >= 50 ? '50+' : '${entries.length}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    '$label player${entries.length == 1 ? '' : 's'} ranked',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }
              final rank = index - 1; // 0-based, since index 0 is the header
              final entry = entries[rank];
              final isCurrentUser = entry.userId == currentUserId;
              return ListTile(
                tileColor: isCurrentUser
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : null,
                leading: CircleAvatar(child: Text('${rank + 1}')),
                title: Text(
                  entry.displayName,
                  style: TextStyle(
                    fontWeight:
                        isCurrentUser ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${entry.testsTaken} test(s) taken'),
                trailing: Text(
                  '${entry.totalMarks} marks',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
