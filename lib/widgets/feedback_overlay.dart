import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Which of the three possible outcomes a just-answered (or just-skipped)
/// question had — decides which animation [FeedbackOverlay] plays.
/// Deliberately a small local enum rather than importing the model
/// layer's `AnswerOutcome` — this widget shouldn't need to know anything
/// about game rules, only which of 3 pictures to draw; `game_screen` maps
/// the real outcome onto this when it mounts the overlay.
enum FeedbackKind { correct, wrong, neutral }

/// Custom-built (no animation/particle package) feedback shown right
/// after a question is scored: a balloon-burst for a correct answer, a
/// hand-drawn red cross for a wrong one, and a plain, non-punitive icon
/// for a skipped/timed-out question (since no marks were lost there —
/// it shouldn't *look* like a penalty).
class FeedbackOverlay extends StatefulWidget {
  const FeedbackOverlay({
    super.key,
    required this.kind,
    required this.onAnimationComplete,
  });

  final FeedbackKind kind;

  /// Called exactly once, when the animation finishes — `game_screen`
  /// advances to the next question (or ends the test) from here.
  final VoidCallback onAnimationComplete;

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasFiredComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.feedbackDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChange);
    _controller.forward();
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_hasFiredComplete) {
      _hasFiredComplete = true;
      widget.onAnimationComplete();
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
      builder: (context, _) => switch (widget.kind) {
        FeedbackKind.correct => _balloonBurst(_controller.value),
        FeedbackKind.wrong => _redCross(_controller.value),
        FeedbackKind.neutral => _neutral(_controller.value),
      },
    );
  }

  /// 8 small "balloons" fly outward from center and fade out, each on a
  /// slightly staggered Interval of the same controller for a light
  /// cascading feel. Built entirely from Transform.translate + Opacity —
  /// no CustomPainter needed for this one.
  Widget _balloonBurst(double t) {
    const balloonCount = 8;
    return Stack(
      alignment: Alignment.center,
      children: List.generate(balloonCount, (i) {
        final angle = i * (2 * math.pi / balloonCount);
        final staggerStart = i * 0.05;
        final localProgress =
            ((t - staggerStart) / (1 - staggerStart)).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(localProgress);
        final distance = 80 * eased;
        return Opacity(
          opacity: 1 - eased,
          child: Transform.translate(
            offset: Offset(math.cos(angle), math.sin(angle)) * distance,
            child: Container(
              width: 20,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors
                    .balloonPalette[i % AppColors.balloonPalette.length],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// A red "X" that draws itself in (via a progress-driven CustomPainter),
  /// with a spring-in scale and a fade-out at the end.
  Widget _redCross(double t) {
    final drawProgress = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));
    final scaleProgress =
        Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0));
    final fadeOpacity =
        t < 0.6 ? 1.0 : 1 - ((t - 0.6) / 0.4).clamp(0.0, 1.0);
    return Opacity(
      opacity: fadeOpacity,
      child: Transform.scale(
        scale: 0.5 + 0.5 * scaleProgress,
        child: SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(painter: _RedCrossPainter(drawProgress)),
        ),
      ),
    );
  }

  /// A plain, calm icon for "time ran out, no marks lost" — deliberately
  /// not styled like a penalty (no red, no cross shape).
  Widget _neutral(double t) {
    final opacity = t < 0.7 ? 1.0 : 1 - ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: const Icon(
        Icons.timer_off_outlined,
        size: 64,
        color: AppColors.neutral,
      ),
    );
  }
}

/// Draws an "X" whose two strokes extend from the center outward as
/// [progress] goes from 0 to 1, rather than appearing instantly.
class _RedCrossPainter extends CustomPainter {
  _RedCrossPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.wrong
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);

    final topLeftEnd = Offset.lerp(center, Offset.zero, progress)!;
    final bottomRightEnd =
        Offset.lerp(center, Offset(size.width, size.height), progress)!;
    canvas.drawLine(topLeftEnd, bottomRightEnd, paint);

    final topRightEnd = Offset.lerp(center, Offset(size.width, 0), progress)!;
    final bottomLeftEnd =
        Offset.lerp(center, Offset(0, size.height), progress)!;
    canvas.drawLine(topRightEnd, bottomLeftEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _RedCrossPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
