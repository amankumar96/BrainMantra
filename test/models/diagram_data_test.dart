import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/diagram_data.dart';

DiagramData roundTrip(DiagramData data) {
  final encoded = jsonEncode(data.toJson());
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return DiagramData.fromJson(decoded);
}

void main() {
  group('DiagramData round-trip per kind', () {
    final cases = <DiagramData>[
      const DiagramData(
        kind: DiagramKind.triangle,
        angles: [50, 65, 65],
        unknownAngleIndex: 2,
      ),
      const DiagramData(kind: DiagramKind.rectangle, dimensions: [8, 5]),
      const DiagramData(kind: DiagramKind.circle, dimensions: [3]),
      const DiagramData(kind: DiagramKind.cylinder, dimensions: [3, 10]),
      const DiagramData(kind: DiagramKind.coordinatePoint, x: 3, y: 4),
      const DiagramData(
        kind: DiagramKind.barGraph,
        categories: ['A', 'B', 'C', 'D'],
        values: [10, 40, 25, 60],
      ),
    ];

    for (final original in cases) {
      test('${original.kind.name} round-trips exactly', () {
        final decoded = roundTrip(original);
        expect(decoded, equals(original));
        expect(decoded.hashCode, equals(original.hashCode));
      });
    }
  });

  test('unset fields round-trip as null, not a decode error', () {
    const original = DiagramData(kind: DiagramKind.coordinatePoint, x: 1, y: 1);
    final decoded = roundTrip(original);
    expect(decoded.angles, isNull);
    expect(decoded.unknownAngleIndex, isNull);
    expect(decoded.dimensions, isNull);
    expect(decoded.categories, isNull);
    expect(decoded.values, isNull);
  });

  test('two instances with the same fields are equal, different id-less '
      'instances with different fields are not', () {
    const a = DiagramData(kind: DiagramKind.rectangle, dimensions: [8, 5]);
    const b = DiagramData(kind: DiagramKind.rectangle, dimensions: [8, 5]);
    const c = DiagramData(kind: DiagramKind.rectangle, dimensions: [9, 5]);
    expect(a, equals(b));
    expect(a, isNot(equals(c)));
  });
}
