import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// A gently animated backdrop for the auth screens: the brain-and-wand
/// mascot as a large, faded watermark plus a handful of slowly bobbing
/// math symbols — sitting on the app's existing soft-blue [AppColors.
/// background] rather than replacing it, so it reads as "the same nice
/// color, made a bit more alive" instead of a clashing new background.
/// Meant to sit *behind* a solid card (e.g. the login form), never behind
/// text that needs to stay legible on its own.
class MathBackgroundDecoration extends StatefulWidget {
  const MathBackgroundDecoration({super.key});

  @override
  State<MathBackgroundDecoration> createState() =>
      _MathBackgroundDecorationState();
}

class _MathBackgroundDecorationState extends State<MathBackgroundDecoration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Scattered by hand rather than randomly, so the layout stays the same
  // (and legible) on every rebuild instead of jumping around.
  static const _symbols = <_FloatingSymbol>[
    _FloatingSymbol('+', left: 0.08, top: 0.06, size: 30, phase: 0),
    _FloatingSymbol('÷', left: 0.80, top: 0.05, size: 26, phase: 1.4),
    _FloatingSymbol('7', left: 0.15, top: 0.26, size: 32, phase: 2.6),
    _FloatingSymbol('×', left: 0.78, top: 0.24, size: 24, phase: 0.8),
    _FloatingSymbol('π', left: 0.06, top: 0.46, size: 26, phase: 3.4),
    _FloatingSymbol('42', left: 0.68, top: 0.44, size: 20, phase: 1.9),
    _FloatingSymbol('√', left: 0.32, top: 0.60, size: 24, phase: 4.2),
    _FloatingSymbol('=', left: 0.85, top: 0.62, size: 22, phase: 2.1),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  // The mascot as a soft watermark, bleeding off the
                  // bottom-right corner rather than sitting as a "sticker"
                  // — keeps focus on the form while still feeling branded.
                  Positioned(
                    right: -w * 0.18,
                    bottom: -h * 0.03,
                    child: Opacity(
                      opacity: 0.10,
                      child: Image.asset(
                        'assets/icons/mascot_transparent.png',
                        width: w * 0.62,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  for (final s in _symbols)
                    Positioned(
                      left: s.left * w,
                      top: s.top * h + _bob(s.phase),
                      child: Text(
                        s.symbol,
                        style: TextStyle(
                          fontSize: s.size,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// A slow, gentle vertical drift (±6px) — enough to feel alive without
  /// distracting from the form in the foreground.
  double _bob(double phase) =>
      sin((_controller.value * 2 * pi) + phase) * 6;
}

class _FloatingSymbol {
  const _FloatingSymbol(
    this.symbol, {
    required this.left,
    required this.top,
    required this.size,
    required this.phase,
  });

  /// Fractions (0–1) of the available width/height — keeps the layout
  /// consistent across phone sizes instead of hardcoded pixel offsets.
  final String symbol;
  final double left;
  final double top;
  final double size;
  final double phase;
}
