import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/widgets/marks_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows question progress and a positive marks total',
      (tester) async {
    await tester.pumpWidget(_wrap(const MarksIndicator(
      currentQuestionNumber: 4,
      totalQuestions: 10,
      marksSoFar: 12,
    )));

    expect(find.text('Question 4 of 10'), findsOneWidget);
    expect(find.text('+12 marks'), findsOneWidget);
  });

  testWidgets('shows a negative marks total without a stray + sign',
      (tester) async {
    await tester.pumpWidget(_wrap(const MarksIndicator(
      currentQuestionNumber: 2,
      totalQuestions: 10,
      marksSoFar: -2,
    )));

    expect(find.text('-2 marks'), findsOneWidget);
  });

  testWidgets('shows a zero marks total plainly', (tester) async {
    await tester.pumpWidget(_wrap(const MarksIndicator(
      currentQuestionNumber: 1,
      totalQuestions: 10,
      marksSoFar: 0,
    )));

    expect(find.text('0 marks'), findsOneWidget);
  });

  testWidgets('a null totalQuestions (Play mode) omits the "of N" part',
      (tester) async {
    await tester.pumpWidget(_wrap(const MarksIndicator(
      currentQuestionNumber: 47,
      totalQuestions: null,
      marksSoFar: 188,
    )));

    expect(find.text('Question 47'), findsOneWidget);
    expect(find.text('+188 marks'), findsOneWidget);
  });
}
