import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/app_language.dart';
import 'package:brain_mantra/widgets/notepad_button.dart';
import 'package:brain_mantra/widgets/notepad_painter.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Finder _pageCanvas(int index) =>
    find.byKey(ValueKey('notepad-canvas-$index'));

/// The painter bound to page [index]'s keyed canvas — used to inspect
/// recorded strokes without any test-only back door, since
/// NotepadPainter.strokes is already a public field. Keyed per page (see
/// notepad_button.dart) so this is unambiguous even if PageView keeps a
/// neighboring page built.
NotepadPainter _pagePainter(WidgetTester tester, int index) {
  final finder = find.descendant(
    of: _pageCanvas(index),
    matching: find.byType(CustomPaint),
  );
  return tester.widget<CustomPaint>(finder).painter as NotepadPainter;
}

void main() {
  testWidgets('tapping the icon opens the notepad sheet', (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    expect(find.text('Scratch Notepad'), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    expect(find.text('Scratch Notepad'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
    expect(find.text('Scratch Notepad'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Scratch Notepad'), findsNothing);
  });

  testWidgets('dragging on the canvas records a stroke on the current page',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    expect(_pagePainter(tester, 0).strokes, isEmpty);

    await tester.drag(_pageCanvas(0), const Offset(40, 40));
    await tester.pump();

    expect(_pagePainter(tester, 0).strokes, isNotEmpty);
  });

  testWidgets('the next-page arrow moves to page 2/5, independent strokes',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    // Draw on page 1.
    await tester.drag(_pageCanvas(0), const Offset(40, 40));
    await tester.pump();
    expect(_pagePainter(tester, 0).strokes, isNotEmpty);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2/5'), findsOneWidget);
    // Page 2 is untouched — its own painter has no strokes, proving each
    // page keeps independent stroke data.
    expect(_pagePainter(tester, 1).strokes, isEmpty);
  });

  testWidgets('the previous-page arrow is disabled on page 1', (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    final prevButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(IconButton),
      ),
    );
    expect(prevButton.onPressed, isNull);
  });

  testWidgets('strokes drawn survive closing and reopening the sheet '
      'within the same session', (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    await tester.drag(_pageCanvas(0), const Offset(40, 40));
    await tester.pump();
    expect(_pagePainter(tester, 0).strokes, isNotEmpty);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    expect(_pagePainter(tester, 0).strokes, isNotEmpty);
  });

  testWidgets('clear page button empties only the current page',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.english)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    await tester.drag(_pageCanvas(0), const Offset(40, 40));
    await tester.pump();
    expect(_pagePainter(tester, 0).strokes, isNotEmpty);

    await tester.tap(find.byIcon(Icons.layers_clear_outlined));
    await tester.pump();

    expect(_pagePainter(tester, 0).strokes, isEmpty);
  });

  testWidgets('Hindi: UI chrome is translated', (tester) async {
    await tester.pumpWidget(
      _wrap(const NotepadButton(language: AppLanguage.hindi)),
    );
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    expect(find.text('स्क्रैच नोटपैड'), findsOneWidget);
  });
}
