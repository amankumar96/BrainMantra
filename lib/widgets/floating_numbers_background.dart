import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// A slow, looping drift of faint numeral/operator glyphs behind Home's
/// centered menu — purely decorative "relaxing" texture, painted as the
/// first child of Home's existing `Stack` so it sits behind everything
/// else with no layout change elsewhere.
///
/// Hand-rolled `CustomPainter` + a single `AnimationController`, matching
/// this codebase's existing animation convention (`diagram_painter.dart`,
/// `feedback_overlay.dart`) rather than a new package. Deliberately uses
/// plain `dart:math`'s [Random] (not `RngService`) — the "never use
/// `Random` directly" rule elsewhere in this codebase exists to keep
/// Daily Challenge's puzzle sequence fair and reproducible across
/// devices; this is decorative-only and never affects gameplay, so that
/// rule doesn't apply here.
class FloatingNumbersBackground extends StatefulWidget {
  const FloatingNumbersBackground({super.key, this.glyphCount = 16});

  /// How many glyphs drift at once — TUNABLE per screen. The Play screen
  /// uses a smaller count than this default so the effect stays subtle
  /// behind its busier foreground (question card, options).
  final int glyphCount;

  @override
  State<FloatingNumbersBackground> createState() =>
      _FloatingNumbersBackgroundState();
}

class _FloatingNumbersBackgroundState extends State<FloatingNumbersBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_FloatingGlyph> _glyphs;

  static const _glyphChars = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '+',
    '×',
    '÷',
    '−',
  ];

  @override
  void initState() {
    super.initState();
    // One full loop every 50s — slow enough to read as "ambient," never
    // distracting from the buttons in front of it.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 50),
    )..repeat();

    final rng = Random();
    _glyphs = List.generate(widget.glyphCount, (_) {
      return _FloatingGlyph(
        char: _glyphChars[rng.nextInt(_glyphChars.length)],
        startX: rng.nextDouble(),
        startY: rng.nextDouble(),
        // Cycles-per-animation-loop and a small sideways drift — varied
        // per glyph so they don't all move in visible lockstep.
        riseSpeed: 0.6 + rng.nextDouble() * 0.8,
        driftX: (rng.nextDouble() - 0.5) * 0.25,
        fontSize: 16 + rng.nextDouble() * 22,
        opacity: 0.05 + rng.nextDouble() * 0.06,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer: purely decorative, must never intercept taps meant
    // for the buttons painted on top of it.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _FloatingNumbersPainter(
              glyphs: _glyphs,
              t: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _FloatingGlyph {
  const _FloatingGlyph({
    required this.char,
    required this.startX,
    required this.startY,
    required this.riseSpeed,
    required this.driftX,
    required this.fontSize,
    required this.opacity,
  });

  final String char;
  final double startX; // fraction of width, 0..1
  final double startY; // fraction of height, 0..1
  final double riseSpeed; // loops completed per full animation cycle
  final double driftX; // sideways drift per cycle, as a width fraction
  final double fontSize;
  final double opacity;
}

class _FloatingNumbersPainter extends CustomPainter {
  _FloatingNumbersPainter({required this.glyphs, required this.t});

  final List<_FloatingGlyph> glyphs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final glyph in glyphs) {
      // Rises upward and wraps back in at the bottom once it drifts off
      // the top — the classic looping-particle-field trick, done with
      // simple modulo arithmetic rather than resetting/replacing glyphs.
      final y = (glyph.startY - t * glyph.riseSpeed) % 1.0;
      final x = (glyph.startX + t * glyph.driftX) % 1.0;

      final textPainter = TextPainter(
        text: TextSpan(
          text: glyph.char,
          style: TextStyle(
            fontSize: glyph.fontSize,
            fontWeight: FontWeight.bold,
            color: AppColors.primary.withValues(alpha: glyph.opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (x < 0 ? x + 1 : x) * size.width,
          (y < 0 ? y + 1 : y) * size.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingNumbersPainter oldDelegate) =>
      oldDelegate.t != t;
}
