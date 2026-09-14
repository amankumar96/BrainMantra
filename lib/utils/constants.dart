import 'package:flutter/material.dart';

/// Colors shared across screens/widgets — kept in one place so the game's
/// palette can be retuned without hunting through every file.
///
/// Brain Mantra's palette: a calm light-blue/indigo pairing for Home and
/// End (the "at rest" screens), a light-green/light-blue Play screen
/// (easier to focus on during active questions), and pink/gold/purple
/// accents pulled from the brain-and-wand logo for celebration moments.
abstract final class AppColors {
  // Light blue + silver theme — easier on the eyes for long play sessions
  // than the original off-white background. Home/End screens only —
  // see [playBackgroundTop]/[playBackgroundBottom] for the Play screen.
  static const Color background = Color(0xFFD9ECFB); // soft light blue
  static const Color silver = Color(0xFFC7CDD1); // surfaces/cards/dividers
  static const Color primary = Color(
    0xFF3F51B5,
  ); // indigo — the Home/End contrast color
  static const Color correct = Color(0xFF2E7D32);
  static const Color wrong = Color(0xFFC62828);
  static const Color neutral = Color(0xFF757575); // skipped/timed-out feedback

  /// The Play screen's background — a light-green-to-light-blue gradient
  /// (used as a [LinearGradient] from [playBackgroundTop] to
  /// [playBackgroundBottom]) rather than Home/End's flat [background], by
  /// deliberate design decision: a distinct, calmer field specifically
  /// for the screen a player spends the most sustained focus time on.
  static const Color playBackgroundTop = Color(0xFFDFF5E6); // light green
  static const Color playBackgroundBottom = Color(0xFFDCEEFC); // light blue

  /// Explicit dark ink for text on [primary]-colored buttons (e.g.
  /// Submit) — Material's seed-derived `onPrimary` isn't guaranteed to
  /// land on a color this legible, so this is set directly rather than
  /// left to theme inference.
  static const Color submitButtonText = Color(0xFF1A2233);

  /// One accent color per difficulty tier (1..4), used e.g. by
  /// marks_indicator/timer_bar to give a visible "this got harder" cue.
  static const List<Color> tierAccents = [
    Color(0xFF43A047), // tier 1 — easy, green
    Color(0xFFFB8C00), // tier 2 — medium, orange
    Color(0xFFE53935), // tier 3 — hard, red
    Color(0xFF6A1B9A), // tier 4 — insane, purple
  ];

  /// Cycled through for the balloon-burst feedback particles — pulled
  /// from the brain-and-wand logo's own palette (pink brain, gold star,
  /// purple/blue/green floating symbols) so the celebration reads as
  /// distinctly "Brain Mantra," not a generic confetti burst.
  static const List<Color> balloonPalette = [
    Color(0xFFFF8FB1), // brain pink
    Color(0xFF4FA8E0), // sky blue
    Color(0xFFFFC94A), // star gold
    Color(0xFFA98BE0), // wand purple
    Color(0xFF79C267), // ÷ green
    Color(0xFFF2607F), // coral pink
    Color(0xFF6EC6E8), // light cyan
    Color(0xFFB39DDB), // lilac
  ];

  /// The meteor-fall (wrong-answer) animation's trail/body color — a
  /// deeper, hotter tone than [wrong] so the falling object reads as an
  /// object, not just a re-tinted version of the plain error color.
  static const Color meteor = Color(0xFFB4472B);
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
  /// How long the balloon-burst (correct) / neutral feedback plays for
  /// before the game moves on to the next question.
  static const Duration feedbackDuration = Duration(milliseconds: 900);

  /// A wrong answer holds much longer: the meteor-fall animation plays,
  /// then the correct answer stays on screen (with a Next button and a
  /// visible countdown) for the rest of this window before
  /// auto-advancing — long enough to actually read and register the
  /// right answer, unlike the quick correct/neutral feedback above.
  static const Duration wrongFeedbackDuration = Duration(seconds: 5);
}

/// Shared text sizes.
abstract final class AppText {
  // TUNABLE — trimmed down from 22 specifically so a long question plus
  // 4 answer options never needs scrolling on a real phone screen (the
  // game screen also now carries a banner ad + marks/timer bar above the
  // question, which didn't exist when 22 was first picked).
  static const double question = 18;
  static const double score = 18;
  static const double timer = 20;

  // TUNABLE — deliberately smaller and separate from [score] (which also
  // drives the Home screen's High Score and the marks indicator, neither
  // of which needed shrinking) — this is specifically for AnswerButton's
  // label, the other half of the "no scrolling" fix.
  static const double answerOption = 15;
}
