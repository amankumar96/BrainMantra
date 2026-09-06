import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/widgets/answer_button.dart';

// Wraps the widget under test in the minimal scaffolding it needs
// (Material app + a Scaffold) so it renders realistically.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('tapping a normal button calls onTap exactly once',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrap(AnswerButton(label: '42', onTap: () => tapCount++)),
    );

    await tester.tap(find.text('42'));
    await tester.pump();

    expect(tapCount, equals(1));
  });

  testWidgets('a disabled button ignores taps even if onTap is provided',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrap(AnswerButton(
        label: '7',
        onTap: () => tapCount++,
        state: AnswerButtonState.disabled,
      )),
    );

    await tester.tap(find.text('7'));
    await tester.pump();

    expect(tapCount, equals(0));
  });

  testWidgets('a null onTap means the button does not call anything',
      (tester) async {
    await tester.pumpWidget(_wrap(const AnswerButton(label: 'x', onTap: null)));

    // Should not throw when tapped with no callback attached.
    await tester.tap(find.text('x'));
    await tester.pump();
  });

  testWidgets('renders the label text for every state', (tester) async {
    for (final state in AnswerButtonState.values) {
      await tester.pumpWidget(
        _wrap(AnswerButton(label: 'Option', onTap: () {}, state: state)),
      );
      expect(find.text('Option'), findsOneWidget);
    }
  });
}
