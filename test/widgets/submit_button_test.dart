import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/widgets/submit_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('disabled (no selection) ignores taps', (tester) async {
    var submitCount = 0;
    await tester.pumpWidget(
      _wrap(SubmitButton(
        hasSelection: false,
        onSubmit: () => submitCount++,
      )),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(submitCount, equals(0));
  });

  testWidgets('enabled (has selection) calls onSubmit when tapped',
      (tester) async {
    var submitCount = 0;
    await tester.pumpWidget(
      _wrap(SubmitButton(
        hasSelection: true,
        onSubmit: () => submitCount++,
      )),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(submitCount, equals(1));
  });
}
