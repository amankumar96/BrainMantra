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
  // correct/neutral share the same short AppDurations.feedbackDuration
  // and "no early-exit path" shape — wrong gets its own group below since
  // it has a completely different (much longer, two-phase, tappable)
  // timeline.
  for (final kind in [FeedbackKind.correct, FeedbackKind.neutral]) {
    testWidgets(
        '$kind: onAnimationComplete fires exactly once after the quick '
        'feedback duration', (tester) async {
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

  testWidgets(
      'correct: does not call onAnimationComplete before the quick '
      'duration elapses', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(_wrap(FeedbackOverlay(
      kind: FeedbackKind.correct,
      onAnimationComplete: () => completeCount++,
    )));

    // Well under the feedback duration.
    await _pumpMillis(tester, 100);
    expect(completeCount, equals(0));
  });

  testWidgets('correct: shows "Correct!" text alongside the balloons',
      (tester) async {
    await tester.pumpWidget(_wrap(FeedbackOverlay(
      kind: FeedbackKind.correct,
      onAnimationComplete: () {},
    )));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Correct!'), findsOneWidget);
  });

  group('wrong answer: meteor fall then a 5s reveal-and-hold', () {
    testWidgets('does not auto-advance before the full hold elapses',
        (tester) async {
      var completeCount = 0;
      await tester.pumpWidget(_wrap(FeedbackOverlay(
        kind: FeedbackKind.wrong,
        correctAnswerText: '42',
        onAnimationComplete: () => completeCount++,
      )));

      // Well under AppDurations.wrongFeedbackDuration (5s).
      await _pumpMillis(tester, 4000);
      expect(completeCount, equals(0));
    });

    testWidgets('auto-advances exactly once once the full hold elapses',
        (tester) async {
      var completeCount = 0;
      await tester.pumpWidget(_wrap(FeedbackOverlay(
        kind: FeedbackKind.wrong,
        correctAnswerText: '42',
        onAnimationComplete: () => completeCount++,
      )));

      await _pumpMillis(
        tester,
        AppDurations.wrongFeedbackDuration.inMilliseconds + 300,
      );
      expect(completeCount, equals(1));

      // Further pumping shouldn't fire it again.
      await _pumpMillis(tester, 300);
      expect(completeCount, equals(1));
    });

    testWidgets(
        'reveals the correct answer and a Next button once the meteor '
        'lands', (tester) async {
      await tester.pumpWidget(_wrap(FeedbackOverlay(
        kind: FeedbackKind.wrong,
        correctAnswerText: '42',
        onAnimationComplete: () {},
      )));

      // Past the ~1.1s meteor-landing threshold, still well under the 5s
      // total hold.
      await _pumpMillis(tester, 1500);

      expect(find.textContaining('42'), findsWidgets);
      expect(find.byKey(const Key('feedback-next-button')), findsOneWidget);
    });

    testWidgets('tapping Next advances immediately, before the hold elapses',
        (tester) async {
      var completeCount = 0;
      await tester.pumpWidget(_wrap(FeedbackOverlay(
        kind: FeedbackKind.wrong,
        correctAnswerText: '42',
        onAnimationComplete: () => completeCount++,
      )));

      await _pumpMillis(tester, 1500); // the reveal has appeared by now
      await tester.tap(find.byKey(const Key('feedback-next-button')));
      await tester.pump();

      expect(completeCount, equals(1));

      // Pumping well past the full 5s hold shouldn't fire it again — the
      // early tap must be the one and only completion.
      await _pumpMillis(tester, 4000);
      expect(completeCount, equals(1));
    });
  });
}
