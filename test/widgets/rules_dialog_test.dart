import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brain_mantra/models/app_language.dart';
import 'package:brain_mantra/services/language_controller.dart';
import 'package:brain_mantra/widgets/rules_dialog.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageController>(
      create: (_) => LanguageController(AppLanguage.english),
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('show() opens the dialog with the scoring rules visible',
      (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => RulesDialog.show(context),
          child: const Text('Open rules'),
        ),
      ),
    ));

    await tester.tap(find.text('Open rules'));
    await tester.pumpAndSettle();

    expect(find.text('How Brain Mantra Works'), findsOneWidget);
    expect(find.textContaining('+4 marks'), findsOneWidget);
    expect(find.textContaining('-2 for a wrong'), findsOneWidget);
    expect(find.textContaining('no penalty'), findsOneWidget);
    expect(find.textContaining('tier 3+'), findsOneWidget);
    expect(find.textContaining('+10 marks'), findsOneWidget);
  });

  testWidgets('"I understand" dismisses the dialog', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => RulesDialog.show(context),
          child: const Text('Open rules'),
        ),
      ),
    ));

    await tester.tap(find.text('Open rules'));
    await tester.pumpAndSettle();
    expect(find.text('How Brain Mantra Works'), findsOneWidget);

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();

    expect(find.text('How Brain Mantra Works'), findsNothing);
  });
}
