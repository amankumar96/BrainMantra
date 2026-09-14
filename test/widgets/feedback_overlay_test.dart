import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/utils/constants.dart';
import 'package:brain_mantra/widgets/feedback_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// See timer_bar_test.dart for why this steps in small increments rather
/// than one big pump(duration) jump — same AnimationController timing
/// edge case applies here.
Future<void> _pumpMillis(WidgetTester tester, int totalMillis) async {
  const step = 100;
  for (var elapsed = 0; elapsed < totalMillis; elapsed += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  for (final kind in FeedbackKind.values) {
    testWidgets('$kind: onAnimationComplete fires exactly once',
        (tester) async {
      var completeCount = 0;
      await tester.pumpWidget(_wrap(FeedbackOverlay(
        kind: kind,
        onAnimationComplete: () => completeCount++,
      )));

      // A little past AppDurations.feedbackDuration for safety margin.
      await _pumpMillis(
        tester,
        AppDurations.feedbackDuration.inMilliseconds + 200,
      );

      expect(completeCount, equals(1));

      // Further pumping shouldn't fire it again.
      await _pumpMillis(tester, 200);
      expect(completeCount, equals(1));
    });
  }

  testWidgets('does not call onAnimationComplete before the duration elapses',
      (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(_wrap(FeedbackOverlay(
      kind: FeedbackKind.correct,
      onAnimationComplete: () => completeCount++,
    )));

    // Well under the feedback duration.
    await _pumpMillis(tester, 100);
    expect(completeCount, equals(0));
  });
}
