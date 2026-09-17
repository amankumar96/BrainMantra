import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/diagram_data.dart';
import 'package:brain_mantra/widgets/answer_button.dart';
import 'package:brain_mantra/widgets/diagram_painter.dart';

const _sampleDiagram = DiagramData(
  kind: DiagramKind.polygon,
  vertices: [0, 0, 0, 3, 2, 2, 2, 1.3, 0.7, 1.3, 0.7, 0],
);

// Wraps the widget under test in the minimal scaffolding it needs
// (Material app + a Scaffold) so it renders realistically.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('tapping a normal button calls onTap exactly once',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrap(AnswerButton(letter: 'A', label: '42', onTap: () => tapCount++)),
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
        letter: 'B',
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
    await tester.pumpWidget(
      _wrap(const AnswerButton(letter: 'C', label: 'x', onTap: null)),
    );

    // Should not throw when tapped with no callback attached.
    await tester.tap(find.text('x'));
    await tester.pump();
  });

  testWidgets('renders the label text for every state', (tester) async {
    for (final state in AnswerButtonState.values) {
      await tester.pumpWidget(
        _wrap(AnswerButton(
          letter: 'A',
          label: 'Option',
          onTap: () {},
          state: state,
        )),
      );
      expect(find.text('Option'), findsOneWidget);
    }
  });

  testWidgets('renders the letter prefix alongside the label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(AnswerButton(letter: 'D', label: 'Option', onTap: () {})),
    );
    expect(find.text('D)'), findsOneWidget);
    expect(find.text('Option'), findsOneWidget);
  });

  group('DiagramAnswerButton', () {
    testWidgets('tapping calls onTap exactly once', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(_wrap(SizedBox(
        width: 80,
        height: 80,
        child: DiagramAnswerButton(
          letter: 'A',
          diagram: _sampleDiagram,
          onTap: () => tapCount++,
        ),
      )));

      await tester.tap(find.byType(DiagramAnswerButton));
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('a disabled button ignores taps even if onTap is provided',
        (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(_wrap(SizedBox(
        width: 80,
        height: 80,
        child: DiagramAnswerButton(
          letter: 'B',
          diagram: _sampleDiagram,
          onTap: () => tapCount++,
          state: AnswerButtonState.disabled,
        ),
      )));

      await tester.tap(find.byType(DiagramAnswerButton));
      await tester.pump();

      expect(tapCount, equals(0));
    });

    testWidgets('paints without throwing for every state and stays clipped '
        'to its own box regardless of the shape drawn', (tester) async {
      for (final state in AnswerButtonState.values) {
        await tester.pumpWidget(_wrap(SizedBox(
          width: 80,
          height: 80,
          child: DiagramAnswerButton(
            letter: 'C',
            diagram: _sampleDiagram,
            onTap: () {},
            state: state,
          ),
        )));
        expect(tester.takeException(), isNull);
        // ClipRect is the hard containment backstop this widget's own doc
        // comment promises — confirm it's actually present, not just that
        // painting happened to not throw.
        expect(find.byType(ClipRect), findsOneWidget);
        // The letter badge renders on top of the diagram for every state.
        expect(find.text('C'), findsOneWidget);
        // Regression coverage: the CustomPaint's render box must actually
        // fill the 80x80 box it was given, not collapse to zero size.
        // "paints without throwing" alone wouldn't have caught a real bug
        // this once hit — wrapping ClipRect/CustomPaint in a Stack without
        // `fit: StackFit.expand` gives them Stack's default loose
        // constraints, and CustomPaint has no intrinsic size of its own,
        // so it silently rendered nothing (every diagram option showed as
        // a blank box) while every other assertion here still passed.
        final diagramPaint = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DiagramPainter,
        );
        // Not an exact 80x80 (the button's own border insets it slightly)
        // — the point is confirming it's nowhere near the degenerate 0x0
        // collapse this test would otherwise miss entirely.
        final size = tester.getSize(diagramPaint);
        expect(size.width, greaterThan(50));
        expect(size.height, greaterThan(50));
      }
    });
  });
}
