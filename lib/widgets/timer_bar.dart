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
    this.extraSeconds = 0,
  });

  final int durationSeconds;

  /// The parent flips this to false the instant an answer is submitted
  /// (or the question times out), so the bar visibly freezes rather than
  /// continuing to drain during the feedback animation.
  final bool isRunning;

  /// Called exactly once, when the countdown reaches zero.
  final VoidCallback onExpired;

  /// Bonus time granted mid-countdown (e.g. a rewarded hint ad). Raising
  /// this across widget updates extends the live countdown by the delta,
  /// in place, without resetting elapsed progress.
  final int extraSeconds;

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

  /// The true total duration once a bonus has been applied — starts equal
  /// to widget.durationSeconds and grows by each extraSeconds delta.
  late int _effectiveTotalSeconds;

  @override
  void initState() {
    super.initState();
    _effectiveTotalSeconds = widget.durationSeconds;
    _controller = AnimationController(
      duration: Duration(seconds: _effectiveTotalSeconds),
      vsync: this,
    )..addStatusListener(_handleStatusChange);
    if (widget.isRunning) {
      _controller.forward();
    }
  }

  /// Stretches the countdown by [deltaSeconds]: keeps the elapsed wall-clock
  /// time fixed, re-expresses it as a smaller fraction of the new (longer)
  /// total, then resumes forwarding from there — so the player keeps
  /// whatever time they'd already used, plus the bonus, rather than having
  /// the bar jump or reset.
  void _extendDuration(int deltaSeconds) {
    if (deltaSeconds <= 0) return;
    final elapsedSeconds = _controller.value * _effectiveTotalSeconds;
    _effectiveTotalSeconds += deltaSeconds;
    final newValue = elapsedSeconds / _effectiveTotalSeconds;
    _controller.duration = Duration(seconds: _effectiveTotalSeconds);
    _controller.value = newValue;
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
    if (widget.extraSeconds > oldWidget.extraSeconds) {
      _extendDuration(widget.extraSeconds - oldWidget.extraSeconds);
    }
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
            (_effectiveTotalSeconds * (1 - elapsedFraction)).ceil();
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
