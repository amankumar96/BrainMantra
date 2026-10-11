import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/notepad_stroke.dart';
import 'package:brain_mantra/widgets/notepad_painter.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, height: 200, child: child)),
    );

void main() {
  testWidgets('empty page: paints without throwing (just the grid)',
      (tester) async {
    await tester.pumpWidget(_wrap(CustomPaint(painter: NotepadPainter([]))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('one stroke: paints without throwing', (tester) async {
    final strokes = [
      NotepadStroke([
        const Offset(10, 10),
        const Offset(20, 20),
        const Offset(30, 15),
      ]),
    ];
    await tester
        .pumpWidget(_wrap(CustomPaint(painter: NotepadPainter(strokes))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('several strokes across the canvas: paints without throwing',
      (tester) async {
    final strokes = [
      NotepadStroke([const Offset(0, 0), const Offset(50, 50)]),
      NotepadStroke([const Offset(100, 100), const Offset(150, 20)]),
      NotepadStroke([const Offset(200, 180)]), // single point, too short to draw
    ];
    await tester
        .pumpWidget(_wrap(CustomPaint(painter: NotepadPainter(strokes))));
    expect(tester.takeException(), isNull);
  });

  test('shouldRepaint is always true — drawing is cheap and strokes '
      'mutate in place', () {
    final painter = NotepadPainter([]);
    final other = NotepadPainter([]);
    expect(painter.shouldRepaint(other), isTrue);
  });
}
