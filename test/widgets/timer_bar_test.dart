import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/widgets/timer_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Advances the test clock in 1-second steps rather than one big jump.
/// A single large `pump(duration)` right after starting an
/// AnimationController can land slightly short of firing
/// AnimationStatus.completed, because the controller's ticker only
/// establishes its elapsed-time baseline once the pump machinery has
/// delivered its first real frame — stepping in smaller increments (the
/// same pattern Flutter's own animation tests use) avoids that off-by-one
/// timing edge case reliably.
Future<void> _pumpSeconds(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('shows the full duration as MM:SS right after starting',
      (tester) async {
    await tester.pumpWidget(
      _wrap(TimerBar(durationSeconds: 125, isRunning: true, onExpired: () {})),
    );
    await tester.pump(); // let the first frame settle
    expect(find.text('02:05'), findsOneWidget);
  });

  testWidgets('calls onExpired exactly once when the duration elapses',
      (tester) async {
    var expiredCount = 0;
    await tester.pumpWidget(
      _wrap(TimerBar(
        durationSeconds: 5,
        isRunning: true,
        onExpired: () => expiredCount++,
      )),
    );

    await _pumpSeconds(tester, 6); // 1s margin past the 5s duration
    expect(expiredCount, equals(1));

    // Pumping further shouldn't fire it again.
    await _pumpSeconds(tester, 2);
    expect(expiredCount, equals(1));
  });

  testWidgets('does not call onExpired if paused before time runs out',
      (tester) async {
    var expiredCount = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(TimerBar(
        key: key,
        durationSeconds: 5,
        isRunning: true,
        onExpired: () => expiredCount++,
      )),
    );

    await _pumpSeconds(tester, 2);

    // Same key, isRunning flips to false — this must pause the SAME
    // State (not tear down and recreate it), matching how game_screen
    // will actually update the widget.
    await tester.pumpWidget(
      _wrap(TimerBar(
        key: key,
        durationSeconds: 5,
        isRunning: false,
        onExpired: () => expiredCount++,
      )),
    );

    // Advance well past the original 5-second duration.
    await _pumpSeconds(tester, 10);

    expect(expiredCount, equals(0));
  });

  testWidgets('a new ValueKey resets the countdown for a new puzzle',
      (tester) async {
    var expiredCount = 0;
    await tester.pumpWidget(
      _wrap(TimerBar(
        key: const ValueKey('puzzle-1'),
        durationSeconds: 5,
        isRunning: true,
        onExpired: () => expiredCount++,
      )),
    );
    await _pumpSeconds(tester, 3);

    // A different key simulates a brand-new puzzle — should start a
    // fresh countdown rather than continuing the old one's progress.
    await tester.pumpWidget(
      _wrap(TimerBar(
        key: const ValueKey('puzzle-2'),
        durationSeconds: 5,
        isRunning: true,
        onExpired: () => expiredCount++,
      )),
    );
    await tester.pump();
    expect(find.text('00:05'), findsOneWidget);
  });

  testWidgets(
      'extraSeconds extends the countdown without resetting elapsed progress',
      (tester) async {
    var expiredCount = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(TimerBar(
        key: key,
        durationSeconds: 10,
        isRunning: true,
        onExpired: () => expiredCount++,
      )),
    );

    await _pumpSeconds(tester, 4); // 6s remaining
    expect(find.text('00:06'), findsOneWidget);

    // Same key, extraSeconds goes from 0 to 60 — a hint-ad reward.
    await tester.pumpWidget(
      _wrap(TimerBar(
        key: key,
        durationSeconds: 10,
        isRunning: true,
        onExpired: () => expiredCount++,
        extraSeconds: 60,
      )),
    );
    await tester.pump();

    // The 4 already-elapsed seconds are preserved, not reset — total is
    // now 70s, so 66s should remain, not a fresh 60s or an unaffected 6s.
    expect(find.text('01:06'), findsOneWidget);

    // The original 10s mark passing (6 more seconds) must NOT fire
    // onExpired now that the real total is 70s.
    await _pumpSeconds(tester, 6);
    expect(expiredCount, equals(0));
  });
}
