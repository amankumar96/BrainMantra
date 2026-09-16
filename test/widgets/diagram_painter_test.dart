import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/diagram_data.dart';
import 'package:brain_mantra/widgets/diagram_painter.dart';

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
  DiagramKind.polygon: DiagramData(
    kind: DiagramKind.polygon,
    vertices: [0, 0, 0, 3, 2, 2, 2, 1.3, 0.7, 1.3, 0.7, 0],
  ),
  DiagramKind.dotGrid: DiagramData(
    kind: DiagramKind.dotGrid,
    points: [0.125, 0.125, 0.875, 0.125, 0.125, 0.875, 0.875, 0.875],
  ),
  DiagramKind.shapeSequence: DiagramData(
    kind: DiagramKind.shapeSequence,
    sideCounts: [3, 4, 5],
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

  group('trianglePoints always fits within the given size', () {
    // Regression coverage for the actual bug reported from a real device:
    // the triangle painter used to scale only against width, so a
    // tall/narrow triangle's apex could land above the diagram's box
    // (canvas y < 0) and overlap whatever sat above it. Each case below
    // is a triangle shape that would have broken that old math.
    const cases = <String, List<double>>{
      'tall and narrow (one very wide angle)': [10, 165, 5],
      'tall and narrow (other side)': [5, 165, 10],
      'near-equilateral': [60, 60, 60],
      'very thin sliver': [2, 2, 176],
      'right triangle': [90, 45, 45],
    };
    const sizes = [
      Size(300, 200),
      Size(140, 200), // narrow - closer to a real phone's split-column width
      Size(200, 90), // short
    ];

    for (final entry in cases.entries) {
      for (final size in sizes) {
        test('${entry.key} @ ${size.width}x${size.height} stays within '
            'bounds', () {
          final points =
              trianglePoints(entry.value, size, padding: 24);
          final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
          for (final p in points) {
            expect(bounds.contains(p), isTrue,
                reason: 'point $p escaped bounds $bounds for '
                    '${entry.key} at $size');
          }
        });
      }
    }
  });

  group('polygonPoints always fits within the given size', () {
    // Same regression rationale as trianglePoints above — a shape's own
    // vertex coordinates use an arbitrary unit scale, never necessarily
    // matching the box it's actually drawn in, so the fit-to-box math is
    // exactly what's under test here, not just "does it paint".
    const cases = <String, List<double>>{
      'small compact shape': [0, 0, 0, 1, 1, 1, 1, 0],
      'wide flat shape': [0, 0, 0, 1, 10, 1, 10, 0],
      'tall narrow shape': [0, 0, 0, 10, 1, 10, 1, 0],
      'irregular hexagon-ish shape': [
        0, 0, 0, 3, 2, 2, 2, 1.3, 0.7, 1.3, 0.7, 0,
      ],
      'shape with negative coordinates (a flipped figure)': [
        0, 0, 0, -3, -2, -2, -2, -1.3, -0.7, -1.3, -0.7, 0,
      ],
    };
    const sizes = [
      Size(300, 200),
      Size(80, 80), // a compact answer-option box, not a full question diagram
      Size(140, 200),
    ];

    for (final entry in cases.entries) {
      for (final size in sizes) {
        test('${entry.key} @ ${size.width}x${size.height} stays within '
            'bounds', () {
          final points = polygonPoints(entry.value, size, padding: 12);
          final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
          for (final p in points) {
            expect(bounds.contains(p), isTrue,
                reason: 'point $p escaped bounds $bounds for '
                    '${entry.key} at $size');
          }
        });
      }
    }
  });

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
