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

/// The fraction of [AppDurations.wrongFeedbackDuration] the meteor-fall
/// entrance itself takes, before the reveal-and-hold phase begins —
/// TUNABLE, chosen to feel like a quick "impact" rather than a slow drop.
const double _meteorLandFraction = 0.22;

/// Custom-built (no animation/particle package) feedback shown right
/// after a question is scored:
/// - **Correct**: a balloon-burst plus a "Correct!" text, over quickly
///   (`AppDurations.feedbackDuration`) — the player was right, no need to
///   linger.
/// - **Wrong**: a meteor falls in, then the correct answer is revealed
///   and held on screen — along with a Next button and a visible
///   countdown — for the rest of `AppDurations.wrongFeedbackDuration`,
///   auto-advancing only once that window elapses (or immediately if the
///   player taps Next first). This is deliberately much slower than
///   correct/neutral: a wrong answer is the one moment a player actually
///   needs time to register what the right answer was.
/// - **Neutral**: a plain, non-punitive icon for a skipped/timed-out
///   question (no marks were lost there — it shouldn't *look* like a
///   penalty), same quick duration as correct.
class FeedbackOverlay extends StatefulWidget {
  const FeedbackOverlay({
    super.key,
    required this.kind,
    required this.onAnimationComplete,
    this.correctAnswerText,
  });

  final FeedbackKind kind;

  /// Called exactly once, when the animation finishes — `game_screen`
  /// advances to the next question (or ends the test) from here. For
  /// [FeedbackKind.wrong], this can fire either because the full
  /// [AppDurations.wrongFeedbackDuration] elapsed, or because the player
  /// tapped Next early — either path is "the player is done looking at
  /// this feedback."
  final VoidCallback onAnimationComplete;

  /// The correct answer to display during [FeedbackKind.wrong]'s
  /// reveal-and-hold phase. Unused for the other two kinds; `game_screen`
  /// always passes `puzzle.correctAnswer.toString()` for a wrong answer.
  final String? correctAnswerText;

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasFiredComplete = false;

  bool get _isWrong => widget.kind == FeedbackKind.wrong;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _isWrong
          ? AppDurations.wrongFeedbackDuration
          : AppDurations.feedbackDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChange);
    _controller.forward();
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) _complete();
  }

  /// Fires [FeedbackOverlay.onAnimationComplete] exactly once — whether
  /// reached by the controller naturally finishing or by the player
  /// tapping Next early (see the Next button below) — and stops the
  /// controller in the early-tap case so it doesn't keep ticking once
  /// this widget's job is done.
  void _complete() {
    if (_hasFiredComplete) return;
    _hasFiredComplete = true;
    _controller.stop();
    widget.onAnimationComplete();
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
        FeedbackKind.correct => _correct(_controller.value),
        FeedbackKind.wrong => _wrong(_controller.value),
        FeedbackKind.neutral => _neutral(_controller.value),
      },
    );
  }

  /// The balloon-burst plus a "Correct!" text, fading in alongside the
  /// balloons and settling for the remainder of the short duration.
  Widget _correct(double t) {
    final textOpacity = (t / 0.4).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        _balloonBurst(t),
        Opacity(
          opacity: textOpacity,
          child: const Text(
            'Correct!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.correct,
            ),
          ),
        ),
      ],
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

  /// Phase 1 (`t < _meteorLandFraction`): a meteor falls in and "lands".
  /// Phase 2 (the rest of the 5s window): the correct answer is revealed
  /// and held, with a Next button + visible countdown.
  Widget _wrong(double t) {
    if (t < _meteorLandFraction) {
      final fallProgress = t / _meteorLandFraction;
      return SizedBox.expand(
        child: CustomPaint(painter: _MeteorPainter(fallProgress)),
      );
    }
    return _wrongReveal(t);
  }

  Widget _wrongReveal(double t) {
    final revealProgress =
        ((t - _meteorLandFraction) / (1 - _meteorLandFraction)).clamp(0.0, 1.0);
    final fadeInOpacity = (revealProgress / 0.2).clamp(0.0, 1.0);
    final totalSeconds = AppDurations.wrongFeedbackDuration.inSeconds;
    final remainingSeconds = (totalSeconds * (1 - t)).ceil().clamp(0, totalSeconds);

    return Opacity(
      opacity: fadeInOpacity,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.wrong, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close, size: 40, color: AppColors.wrong),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Correct answer: ${widget.correctAnswerText ?? '—'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                key: const Key('feedback-next-button'),
                onPressed: _complete,
                child: Text('Next ($remainingSeconds s)'),
              ),
            ],
          ),
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

/// Draws a falling "meteor" (a filled circle with a fading trail behind
/// it) moving from just above the top of the box to a landing point,
/// easing in like something accelerating under gravity, as [progress]
/// goes from 0 to 1.
class _MeteorPainter extends CustomPainter {
  _MeteorPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeIn.transform(progress.clamp(0.0, 1.0));
    final startY = -0.15 * size.height;
    final endY = 0.5 * size.height;
    final x = size.width / 2;
    final y = startY + (endY - startY) * eased;

    final trailPaint = Paint()
      ..color = AppColors.meteor.withValues(alpha: 0.35)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y - 50), Offset(x, y), trailPaint);

    final bodyPaint = Paint()..color = AppColors.meteor;
    canvas.drawCircle(Offset(x, y), 16, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
