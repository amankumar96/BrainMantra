/// Which shape/visualization a [DiagramData] describes. `diagram_painter.dart`
/// switches on this to decide how to draw it.
enum DiagramKind { triangle, rectangle, circle, cylinder, coordinatePoint, barGraph }

/// Everything a diagram painter needs to render one diagram, plus enough
/// raw numeric data for a test to independently re-derive a puzzle's
/// correct answer (e.g. `180 - angles[0] - angles[1]`) without parsing
/// `questionText` or reaching into generator internals — the same
/// self-validation principle every other generator in this codebase
/// already follows.
///
/// One shared field set, used differently per [kind] — see each field's
/// own doc comment for which kind(s) actually populate it. Dart has no
/// tagged unions, and the project doesn't use a codegen package for one
/// (`freezed` etc.), so this is a plain nullable-fields container, the
/// same trade-off `Puzzle.correctAnswer` already makes with `dynamic`.
class DiagramData {
  final DiagramKind kind;

  /// [DiagramKind.triangle] only: the triangle's three interior angles in
  /// degrees, in order. Always sums to exactly 180.
  final List<double>? angles;

  /// [DiagramKind.triangle] only: which index into [angles] is the "?"
  /// the question asks for (the other two are shown labeled on the
  /// diagram).
  final int? unknownAngleIndex;

  /// [DiagramKind.rectangle]: `[length, width]`. [DiagramKind.circle]:
  /// `[radius]`. [DiagramKind.cylinder]: `[radius, height]`.
  final List<double>? dimensions;

  /// [DiagramKind.coordinatePoint] only: the plotted point.
  final double? x;
  final double? y;

  /// [DiagramKind.barGraph] only: category labels and their values, same
  /// length and order (`categories[i]` is the label for `values[i]`).
  final List<String>? categories;
  final List<int>? values;

  const DiagramData({
    required this.kind,
    this.angles,
    this.unknownAngleIndex,
    this.dimensions,
    this.x,
    this.y,
    this.categories,
    this.values,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'angles': angles,
        'unknownAngleIndex': unknownAngleIndex,
        'dimensions': dimensions,
        'x': x,
        'y': y,
        'categories': categories,
        'values': values,
      };

  factory DiagramData.fromJson(Map<String, dynamic> json) {
    return DiagramData(
      kind: DiagramKind.values.byName(json['kind'] as String),
      angles: (json['angles'] as List?)?.map((v) => (v as num).toDouble()).toList(),
      unknownAngleIndex: json['unknownAngleIndex'] as int?,
      dimensions:
          (json['dimensions'] as List?)?.map((v) => (v as num).toDouble()).toList(),
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      categories: (json['categories'] as List?)?.map((v) => v as String).toList(),
      values: (json['values'] as List?)?.map((v) => v as int).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiagramData &&
        other.kind == kind &&
        _listEquals(other.angles, angles) &&
        other.unknownAngleIndex == unknownAngleIndex &&
        _listEquals(other.dimensions, dimensions) &&
        other.x == x &&
        other.y == y &&
        _listEquals(other.categories, categories) &&
        _listEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hash(
        kind,
        angles == null ? null : Object.hashAll(angles!),
        unknownAngleIndex,
        dimensions == null ? null : Object.hashAll(dimensions!),
        x,
        y,
        categories == null ? null : Object.hashAll(categories!),
        values == null ? null : Object.hashAll(values!),
      );

  @override
  String toString() => 'DiagramData(kind: $kind, angles: $angles, '
      'unknownAngleIndex: $unknownAngleIndex, dimensions: $dimensions, '
      'x: $x, y: $y, categories: $categories, values: $values)';
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
