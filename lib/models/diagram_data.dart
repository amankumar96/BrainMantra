import 'dart:math' show cos, pi, sin;

/// Flattened `[x0, y0, x1, y1, ...]` vertices of a regular polygon with
/// [sides] sides, inscribed in a unit circle and rotated so the first
/// vertex points straight up — shared by every generator that builds a
/// [DiagramKind.polygon] regular shape (figure series' options, the
/// answer choices in a shape-progression puzzle) and by
/// `diagram_painter.dart`'s [DiagramKind.shapeSequence] renderer, so
/// there's exactly one definition of "what a square/pentagon/hexagon
/// looks like" for this app to ever disagree with itself about.
List<double> regularPolygonVertices(int sides) {
  final vertices = <double>[];
  for (var i = 0; i < sides; i++) {
    final angle = -pi / 2 + (2 * pi * i / sides);
    vertices.addAll([cos(angle), sin(angle)]);
  }
  return vertices;
}

/// Which shape/visualization a [DiagramData] describes. `diagram_painter.dart`
/// switches on this to decide how to draw it.
enum DiagramKind {
  triangle,
  rectangle,
  circle,
  cylinder,
  coordinatePoint,
  barGraph,

  /// An arbitrary closed polygon — used for diagram-as-answer-option
  /// puzzles (Phase 13: mirror/water images), where each of the 4 options
  /// is itself a small rendered shape rather than text. See [vertices].
  polygon,

  /// A bordered square with a handful of dots marking hole positions
  /// (Phase 14: paper folding) — both the folded-sheet reference diagram
  /// (one dot) and each unfold-pattern answer option (several dots). See
  /// [points].
  dotGrid,

  /// Several regular polygons drawn left to right in one box (Phase 14:
  /// figure series) — the question's reference diagram showing a shape
  /// progression (e.g. triangle, square, pentagon, ?). See [sideCounts].
  shapeSequence,
}

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

  /// [DiagramKind.polygon] only: a closed shape's vertices, flattened as
  /// `[x0, y0, x1, y1, ...]` in an arbitrary (not necessarily 0..1) unit
  /// space — `DiagramPainter` fits the shape's own bounding box to
  /// whatever box it's actually given, the same "measure first, then pick
  /// one scale for both axes" technique `trianglePoints` already uses, so
  /// the coordinate scale here never needs to match the eventual on-screen
  /// size.
  final List<double>? vertices;

  /// [DiagramKind.dotGrid] only: hole/dot positions, flattened as
  /// `[x0, y0, x1, y1, ...]`, each in `[0, 1]` — a fraction of the way
  /// across a unit square frame (not a shape's own bounding box, unlike
  /// [vertices] — a dot grid must show *where in the square* each hole
  /// is, so its coordinate space is fixed, not fit-to-content).
  final List<double>? points;

  /// [DiagramKind.shapeSequence] only: one regular polygon's side count
  /// per entry, drawn left to right in order (e.g. `[3, 4, 5]` draws a
  /// triangle, then a square, then a pentagon).
  final List<int>? sideCounts;

  const DiagramData({
    required this.kind,
    this.angles,
    this.unknownAngleIndex,
    this.dimensions,
    this.x,
    this.y,
    this.categories,
    this.values,
    this.vertices,
    this.points,
    this.sideCounts,
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
        'vertices': vertices,
        'points': points,
        'sideCounts': sideCounts,
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
      vertices:
          (json['vertices'] as List?)?.map((v) => (v as num).toDouble()).toList(),
      points: (json['points'] as List?)?.map((v) => (v as num).toDouble()).toList(),
      sideCounts: (json['sideCounts'] as List?)?.map((v) => v as int).toList(),
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
        _listEquals(other.values, values) &&
        _listEquals(other.vertices, vertices) &&
        _listEquals(other.points, points) &&
        _listEquals(other.sideCounts, sideCounts);
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
        vertices == null ? null : Object.hashAll(vertices!),
        points == null ? null : Object.hashAll(points!),
        sideCounts == null ? null : Object.hashAll(sideCounts!),
      );

  @override
  String toString() => 'DiagramData(kind: $kind, angles: $angles, '
      'unknownAngleIndex: $unknownAngleIndex, dimensions: $dimensions, '
      'x: $x, y: $y, categories: $categories, values: $values, '
      'vertices: $vertices, points: $points, sideCounts: $sideCounts)';
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
