import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// A countdown display: a live `MM:SS` readout plus a slim shrinking
/// progress bar underneath. Now that questions can run up to 30 minutes,
/// a shrinking bar alone (the original fast-blitz design) wouldn't be
/// readable — the text is the primary cue, the bar a secondary one.
///
/// Give this widget a `key` derived from the current puzzle (e.g.
/// `ValueKey(puzzle.id)`) from the caller — a new key makes Flutter tear
/// down and rebuild this whole State, which is what gives each new
/// question a fresh, correctly-timed countdown with no manual reset logic.
class TimerBar extends StatefulWidget {
  const TimerBar({
    super.key,
    required this.durationSeconds,
    required this.isRunning,
    required this.onExpired,
  });

  final int durationSeconds;

  /// The parent flips this to false the instant an answer is submitted
  /// (or the question times out), so the bar visibly freezes rather than
  /// continuing to drain during the feedback animation.
  final bool isRunning;

  /// Called exactly once, when the countdown reaches zero.
  final VoidCallback onExpired;

  @override
  State<TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // AnimationStatus.completed can in principle be reported more than once
  // in edge cases (e.g. a stray rebuild); this guards onExpired firing
  // more than once per question.
  bool _hasFiredExpired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.durationSeconds),
      vsync: this,
    )..addStatusListener(_handleStatusChange);
    if (widget.isRunning) {
      _controller.forward();
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_hasFiredExpired) {
      _hasFiredExpired = true;
      widget.onExpired();
    }
  }

  @override
  void didUpdateWidget(covariant TimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause/resume in response to the parent's isRunning flag — this is
    // what makes the bar freeze during the feedback animation instead of
    // continuing to drain underneath it.
    if (!widget.isRunning && oldWidget.isRunning) {
      _controller.stop();
    } else if (widget.isRunning && !oldWidget.isRunning) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsedFraction = _controller.value;
        final remainingSeconds =
            (widget.durationSeconds * (1 - elapsedFraction)).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatMmSs(remainingSeconds),
              style: const TextStyle(
                fontSize: AppText.timer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: LinearProgressIndicator(
                value: 1 - elapsedFraction,
                minHeight: 6,
                backgroundColor: Colors.black12,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Formats a whole number of seconds as `MM:SS`, e.g. 125 -> "02:05".
String _formatMmSs(int totalSeconds) {
  final clamped = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = clamped ~/ 60;
  final seconds = clamped % 60;
  final minutesText = minutes.toString().padLeft(2, '0');
  final secondsText = seconds.toString().padLeft(2, '0');
  return '$minutesText:$secondsText';
}
