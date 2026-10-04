import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brain_mantra/models/app_language.dart';
import 'package:brain_mantra/screens/delete_account_screen.dart';
import 'package:brain_mantra/services/language_controller.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageController>(
      create: (_) => LanguageController(AppLanguage.english),
      child: MaterialApp(home: child),
    );

void main() {
  Widget wrap() => _wrap(const DeleteAccountScreen());

  testWidgets('explains what will be deleted and offers Delete/Cancel',
      (tester) async {
    await tester.pumpWidget(wrap());

    expect(
      find.text(
        'Deleting your account is permanent and cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your persistent score'), findsOneWidget);
    expect(find.text('Your day streak'), findsOneWidget);
    expect(find.text('Delete My Account'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets(
      'confirming Delete surfaces an error (Supabase is not initialized '
      'in this test) rather than crashing or silently signing out',
      (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Delete My Account'));
    await tester.pump(); // show the loading spinner
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not delete your account'), findsOneWidget);
    // Still here — a failed delete must not navigate away.
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(find.text('Delete My Account'), findsOneWidget); // re-enabled
  });

  testWidgets('Cancel returns to the previous screen without deleting '
      'anything', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
