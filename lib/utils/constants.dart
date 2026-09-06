import 'package:flutter/material.dart';

/// Colors shared across screens/widgets — kept in one place so the game's
/// palette can be retuned without hunting through every file.
abstract final class AppColors {
  static const Color background = Color(0xFFF7F7FB);
  static const Color primary = Color(0xFF3F51B5);
  static const Color correct = Color(0xFF2E7D32);
  static const Color wrong = Color(0xFFC62828);
  static const Color neutral = Color(0xFF757575); // skipped/timed-out feedback

  /// One accent color per difficulty tier (1..4), used e.g. by
  /// marks_indicator/timer_bar to give a visible "this got harder" cue.
  static const List<Color> tierAccents = [
    Color(0xFF43A047), // tier 1 — easy, green
    Color(0xFFFB8C00), // tier 2 — medium, orange
    Color(0xFFE53935), // tier 3 — hard, red
    Color(0xFF6A1B9A), // tier 4 — insane, purple
  ];

  /// Cycled through for the balloon-burst feedback particles.
  static const List<Color> balloonPalette = [
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFF7043),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
  ];
}

/// Shared spacing scale — use these instead of one-off pixel values.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Shared animation/timing durations.
abstract final class AppDurations {
  /// How long the balloon-burst / red-cross / neutral feedback plays for
  /// before the game moves on to the next question.
  static const Duration feedbackDuration = Duration(milliseconds: 900);
}

/// Shared text sizes.
abstract final class AppText {
  static const double question = 22;
  static const double score = 18;
  static const double timer = 20;
}
