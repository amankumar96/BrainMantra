import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/leaderboard_service.dart';
import '../utils/constants.dart';

/// Shows everyone ranked by their persistent total score (Play + Daily
/// Challenge combined — see `LeaderboardService`'s own doc comment) among
/// players active in the last 30 days: a Top 3 podium, a ranked list below
/// it, and — only when the signed-in player isn't already visible in that
/// list — a separate "Your Position" card pinned at the bottom.
///
/// All names/ranks/marks rendered here come straight from
/// [LeaderboardService] (ultimately Supabase's `profiles` table) — nothing
/// on this screen is hardcoded sample data. The one exception is
/// [LeaderboardEntry.avatarUrl], which is always null today (see that
/// field's own doc comment for why) — every avatar therefore falls back to
/// a generated initials badge, an intentional, original, copyright-safe
/// placeholder rather than a stock illustration.
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

  /// Sequential, not `Future.wait([...])` — when both underlying Supabase
  /// calls fail at once (e.g. every widget test, since Supabase is never
  /// initialized there), `Future.wait` only ever surfaces the *first* of
  /// the two errors through the `Future` it returns; the second call's
  /// own independent rejection is then never observed by anyone, which
  /// Dart's zone error-tracking reports as an unhandled exception the
  /// next time anything drains microtasks — surfacing, confusingly, as a
  /// crash the next time a completely unrelated `tester.tap()` runs,
  /// rather than as this screen's own error state. Awaiting one at a time
  /// means only ever one Future is in flight, always properly handled,
  /// at the minor cost of one extra sequential round-trip over the
  /// (already rare) case where both calls are actually needed.
  Future<_LeaderboardData> _load() async {
    final topTen = await LeaderboardService.fetchTopRankings(limit: 10);
    final myEntryAndRank = await LeaderboardService.fetchMyEntryAndRank();
    return _LeaderboardData(topTen: topTen, myEntryAndRank: myEntryAndRank);
  }

  /// The Retry button's action — re-runs the exact same fetch [initState]
  /// did, replacing the future the `FutureBuilder` watches.
  ///
  /// Two things here are each independently required, confirmed against a
  /// real failing widget test:
  /// 1. A block body, not `setState(() => _dataFuture = _load())` — that
  ///    arrow form's closure would itself evaluate to the assignment's
  ///    value (the new `Future`), and `setState` explicitly asserts
  ///    against a callback that returns a `Future`.
  /// 2. `future.ignore()` on the new future *before* handing it to
  ///    `FutureBuilder` — unlike [initState] (where `FutureBuilder`
  ///    subscribes to `_dataFuture` in the very same synchronous build
  ///    that creates it), a future created here can, depending on timing,
  ///    finish rejecting before `FutureBuilder`'s `didUpdateWidget`
  ///    actually resubscribes to the *new* future next frame. A `Future`
  ///    that completes with an error before anything has ever attached an
  ///    error handler to it is reported by Dart's zone machinery as an
  ///    unhandled exception — surfacing, confusingly, as a crash the next
  ///    time anything drains microtasks (here, `tester.tap()` itself),
  ///    not as this screen's own error state. `Future.ignore()` is the
  ///    Dart-provided way to mark a future's error as "already handled by
  ///    something else" without altering what `FutureBuilder` itself
  ///    still observes from the very same future object.
  void _retry() {
    final future = _load();
    future.ignore();
    setState(() {
      _dataFuture = future;
    });
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

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About the Leaderboard'),
        content: const Text(
          'Ranked by total marks earned across Play and Daily Challenge, '
          'among players active in the last 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _LeaderboardHeader(onInfoTap: _showInfoDialog),
          Expanded(
            child: FutureBuilder<_LeaderboardData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingSkeleton();
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _retry);
                }
                final data = snapshot.data!;
                if (data.topTen.isEmpty) {
                  return const _EmptyState();
                }

                final topThree = data.topTen.take(3).toList();
                final rest = data.topTen.length > 3
                    ? data.topTen.sublist(3)
                    : const <LeaderboardEntry>[];
                final myRank = data.myEntryAndRank?.rank;
                // Only shown when the player's real rank falls outside
                // this fetch's visible window — if they're already
                // somewhere in topThree/rest, their row there is
                // highlighted in place instead (see isCurrentUser below).
                final showYourPosition =
                    myRank != null && myRank > data.topTen.length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LeaderboardPodium(
                        topThree: topThree,
                        currentUserId: currentUserId,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LeaderboardListSection(
                        entries: rest,
                        startRank: 4,
                        currentUserId: currentUserId,
                      ),
                      if (showYourPosition)
                        YourPositionCard(
                          rank: myRank,
                          entry: data.myEntryAndRank!.entry,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The custom gradient header — back arrow, centered "Leaderboard" title
/// with a "Last 30 Days" period indicator beneath it (visually ready for a
/// future period-picker; not yet functional), and an info icon. Royal
/// blue/indigo gradient + a couple of soft wave curves, matching the same
/// hand-rolled-`CustomPainter` decorative convention `home_screen.dart`
/// already established (kept as its own small private painter here rather
/// than shared, to keep this change scoped to this one screen).
class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({required this.onInfoTap});

  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        MediaQuery.paddingOf(context).top + AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LeaderboardWavePainter()),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    // A visual placeholder for a future time-period picker
                    // — not yet wired to anything, per the current spec.
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Last 30 Days',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              Icons.expand_more,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                tooltip: 'About the leaderboard',
                onPressed: onInfoTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void drawWave(double baseline, double amplitude, double opacity) {
      final path = Path()..moveTo(-20, baseline);
      path.quadraticBezierTo(
        size.width * 0.25,
        baseline - amplitude,
        size.width * 0.5,
        baseline,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        baseline + amplitude,
        size.width + 20,
        baseline,
      );
      path.lineTo(size.width + 20, size.height + 20);
      path.lineTo(-20, size.height + 20);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    drawWave(size.height * 0.75, 12, 0.06);
    drawWave(size.height * 0.88, 8, 0.05);
  }

  @override
  bool shouldRepaint(covariant _LeaderboardWavePainter oldDelegate) => false;
}

/// The Top 3 podium — rank 2 on the left, rank 1 centered and elevated,
/// rank 3 on the right. Renders whatever [topThree] actually holds (1, 2,
/// or 3 entries — a brand-new leaderboard may not have 3 players yet)
/// without breaking the layout. Every name/rank/marks value comes from
/// [topThree] itself; nothing here is hardcoded.
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.topThree,
    this.currentUserId,
  });

  /// 1 to 3 entries, index 0 = rank 1 (already sliced by the caller —
  /// this widget doesn't re-derive rank from anywhere but list position).
  final List<LeaderboardEntry> topThree;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    Widget slotFor(int rank) {
      if (rank > topThree.length) return const Spacer();
      final entry = topThree[rank - 1];
      return Expanded(
        child: _PodiumSlot(
          rank: rank,
          entry: entry,
          isCurrentUser: entry.userId == currentUserId,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // A few low-alpha sparkles behind the podium — tasteful, not
        // cluttered, per the design brief.
        const Positioned(
          top: 0,
          left: 12,
          child: Icon(
            Icons.auto_awesome,
            size: 16,
            color: AppColors.leaderboardGold,
          ),
        ),
        const Positioned(
          top: 8,
          right: 20,
          child: Icon(
            Icons.auto_awesome,
            size: 12,
            color: AppColors.leaderboardGold,
          ),
        ),
        const Positioned(
          top: -4,
          right: 90,
          child: Icon(
            Icons.auto_awesome,
            size: 10,
            color: AppColors.leaderboardGold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              slotFor(2),
              const SizedBox(width: AppSpacing.xs),
              slotFor(1),
              const SizedBox(width: AppSpacing.xs),
              slotFor(3),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => AppColors.leaderboardGold,
      2 => AppColors.leaderboardSilver,
      _ => AppColors.leaderboardBronze,
    };
    final avatarSize = rank == 1 ? 72.0 : 56.0;
    final baseHeight = switch (rank) {
      1 => 84.0,
      2 => 60.0,
      _ => 44.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            LeaderboardAvatar(
              entry: entry,
              size: avatarSize,
              ringColor: isCurrentUser
                  ? AppColors.leaderboardCurrentUser
                  : medalColor,
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: medalColor, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 14 : 12,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 12, color: AppColors.leaderboardGold),
            const SizedBox(width: 2),
            Text(
              '${entry.totalScore}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          height: baseHeight,
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// The ranked list below the podium — one [LeaderboardRow] per entry in
/// [entries], ranked starting at [startRank] (4, immediately after the
/// podium's 1-3).
class LeaderboardListSection extends StatelessWidget {
  const LeaderboardListSection({
    super.key,
    required this.entries,
    required this.startRank,
    this.currentUserId,
  });

  final List<LeaderboardEntry> entries;
  final int startRank;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: LeaderboardRow(
              rank: startRank + i,
              entry: entries[i],
              isCurrentUser: entries[i].userId == currentUserId,
            ),
          ),
      ],
    );
  }
}

/// One ranked row: `rank  avatar  name [You]  ★ marks`, per the requested
/// visual structure. `isCurrentUser` only ever adds a small "You" chip and
/// a green tint — the real [entry] name/marks always render, never
/// replaced by static copy.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.leaderboardCurrentUser.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.leaderboardCurrentUser
              : AppColors.silver,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          LeaderboardAvatar(entry: entry, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.leaderboardCurrentUser,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.star, size: 14, color: AppColors.leaderboardGold),
          const SizedBox(width: 2),
          Text(
            '${entry.totalScore}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Pinned at the bottom of the scroll content only when the signed-in
/// player's real rank falls outside the fetched top-10 window — the
/// current user is never assumed to be rank 1 or anywhere in particular.
class YourPositionCard extends StatelessWidget {
  const YourPositionCard({super.key, required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.leaderboardCurrentUser.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.leaderboardCurrentUser, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.leaderboardCurrentUser,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          LeaderboardAvatar(entry: entry, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Position',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.leaderboardCurrentUser,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Icon(Icons.star, size: 14, color: AppColors.leaderboardGold),
          const SizedBox(width: 2),
          Text(
            '${entry.totalScore}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A circular avatar for [entry] — an [entry.avatarUrl] image when one is
/// present, otherwise an original generated placeholder: a solid color
/// (deterministically picked from [entry.userId], so the same player
/// always gets the same color) holding their initials. No external
/// artwork, no stock illustrations — every pixel is drawn by Flutter
/// itself.
class LeaderboardAvatar extends StatelessWidget {
  const LeaderboardAvatar({
    super.key,
    required this.entry,
    this.size = 40,
    this.ringColor,
  });

  final LeaderboardEntry entry;
  final double size;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final url = entry.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColorFor(
          entry.userId.isNotEmpty ? entry.userId : entry.displayName,
        ),
        border: ringColor != null
            ? Border.all(color: ringColor!, width: 2.5)
            : null,
      ),
      alignment: Alignment.center,
      child: (url != null && url.isNotEmpty)
          ? ClipOval(
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialsText(entry, size),
              ),
            )
          : _InitialsText(entry, size),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText(this.entry, this.size);

  final LeaderboardEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      _initialsFor(entry.displayName),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.36,
      ),
    );
  }
}

/// A stable color from [seed] (the player's own userId, so it never
/// changes between fetches) — a plain string hash into a small fixed
/// palette, deliberately distinct from the gold/silver/bronze medal
/// colors so an avatar is never confused with its own medal.
Color _avatarColorFor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return AppColors.avatarPalette[hash % AppColors.avatarPalette.length];
}

/// Up to two initials from [name] — e.g. "Aarav Sharma" -> "AS", "Aarav"
/// -> "A", "" -> "?".
String _initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts[0].isNotEmpty ? parts[0][0] : '';
  final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
  final initials = (first + second).toUpperCase();
  return initials.isEmpty ? '?' : initials;
}

/// A pulsing gray placeholder rectangle — the building block of
/// [_LoadingSkeleton]. A small hand-rolled shimmer (an `AnimationController`
/// looping opacity) rather than a new shimmer package, matching this
/// codebase's existing animation convention.
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.silver.withValues(
            alpha: 0.25 + _controller.value * 0.25,
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Shown while the leaderboard is loading — shimmering placeholder shapes
/// approximating the podium + list, rather than a bare spinner or (worse)
/// fake leaderboard values.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('leaderboard-loading-skeleton'),
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _ShimmerBox(width: 56, height: 56, borderRadius: 28),
              SizedBox(width: AppSpacing.md),
              _ShimmerBox(width: 72, height: 72, borderRadius: 36),
              SizedBox(width: AppSpacing.md),
              _ShimmerBox(width: 56, height: 56, borderRadius: 28),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ShimmerBox(width: double.infinity, height: 56),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: AppColors.silver,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No leaderboard entries yet. Start solving to make your mark!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.wrong),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load the leaderboard. Please try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
