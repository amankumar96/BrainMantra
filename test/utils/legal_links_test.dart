import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/utils/legal_links.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('every legal URL is https and ends in the right page', () {
    expect(LegalLinks.baseUrl, startsWith('https://'));
    expect(LegalLinks.baseUrl, endsWith('/'));
    expect(LegalLinks.privacyPolicy.path, endsWith('privacy.html'));
    expect(LegalLinks.termsOfService.path, endsWith('terms.html'));
    expect(LegalLinks.deleteAccount.path, endsWith('delete-account.html'));
  });

  testWidgets('shows both links and opens the right URLs when tapped',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_wrap(LegalLinksRow(opener: (u) async {
      opened.add(u);
      return true;
    })));

    await tester.tap(find.text('Privacy Policy'));
    await tester.tap(find.text('Terms of Service'));
    await tester.pump();

    expect(opened, [LegalLinks.privacyPolicy, LegalLinks.termsOfService]);
  });

  testWidgets('a failed launch shows a friendly message, never crashes',
      (tester) async {
    await tester.pumpWidget(_wrap(LegalLinksRow(opener: (_) async => false)));

    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();

    expect(find.textContaining("Couldn't open the link"), findsOneWidget);
  });
}
