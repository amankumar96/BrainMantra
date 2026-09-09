import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/models/diagram_data.dart';
import 'package:math_blitz/widgets/diagram_painter.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, height: 200, child: child)),
    );

const _sampleByKind = <DiagramKind, DiagramData>{
  DiagramKind.triangle: DiagramData(
    kind: DiagramKind.triangle,
    angles: [50, 65, 65],
    unknownAngleIndex: 2,
  ),
  DiagramKind.rectangle:
      DiagramData(kind: DiagramKind.rectangle, dimensions: [8, 5]),
  DiagramKind.circle: DiagramData(kind: DiagramKind.circle, dimensions: [3]),
  DiagramKind.cylinder:
      DiagramData(kind: DiagramKind.cylinder, dimensions: [3, 10]),
  DiagramKind.coordinatePoint:
      DiagramData(kind: DiagramKind.coordinatePoint, x: 3, y: 4),
  DiagramKind.barGraph: DiagramData(
    kind: DiagramKind.barGraph,
    categories: ['A', 'B', 'C', 'D'],
    values: [10, 40, 25, 60],
  ),
};

void main() {
  for (final entry in _sampleByKind.entries) {
    testWidgets('${entry.key}: paints without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(CustomPaint(painter: DiagramPainter(entry.value))),
      );
      expect(tester.takeException(), isNull);
    });
  }

  // Every unknownAngleIndex position, since the triangle painter labels
  // whichever vertex is "?" — a bug in one branch shouldn't be masked by
  // only ever testing index 2.
  for (final unknownIndex in [0, 1, 2]) {
    testWidgets('triangle with unknownAngleIndex $unknownIndex paints '
        'without throwing', (tester) async {
      await tester.pumpWidget(_wrap(CustomPaint(
        painter: DiagramPainter(DiagramData(
          kind: DiagramKind.triangle,
          angles: const [50, 65, 65],
          unknownAngleIndex: unknownIndex,
        )),
      )));
      expect(tester.takeException(), isNull);
    });
  }

  group('shouldRepaint', () {
    test('false when the underlying DiagramData is equal', () {
      const a = DiagramData(kind: DiagramKind.circle, dimensions: [3]);
      const b = DiagramData(kind: DiagramKind.circle, dimensions: [3]);
      expect(DiagramPainter(a).shouldRepaint(DiagramPainter(b)), isFalse);
    });

    test('true when the underlying DiagramData differs', () {
      const a = DiagramData(kind: DiagramKind.circle, dimensions: [3]);
      const b = DiagramData(kind: DiagramKind.circle, dimensions: [5]);
      expect(DiagramPainter(a).shouldRepaint(DiagramPainter(b)), isTrue);
    });
  });
}
