import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/widgets/rules_dialog.dart';

void main() {
  testWidgets('show() opens the dialog with the scoring rules visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => RulesDialog.show(context),
          child: const Text('Open rules'),
        ),
      ),
    ));

    await tester.tap(find.text('Open rules'));
    await tester.pumpAndSettle();

    expect(find.text('How MathBlitz Works'), findsOneWidget);
    expect(find.textContaining('+4 marks'), findsOneWidget);
    expect(find.textContaining('-2 for a wrong'), findsOneWidget);
    expect(find.textContaining('no penalty'), findsOneWidget);
    expect(find.textContaining('tier 3+'), findsOneWidget);
    expect(find.textContaining('+10 marks'), findsOneWidget);
  });

  testWidgets('"I understand" dismisses the dialog', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => RulesDialog.show(context),
          child: const Text('Open rules'),
        ),
      ),
    ));

    await tester.tap(find.text('Open rules'));
    await tester.pumpAndSettle();
    expect(find.text('How MathBlitz Works'), findsOneWidget);

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();

    expect(find.text('How MathBlitz Works'), findsNothing);
  });
}
