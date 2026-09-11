import 'dart:math' show cos, max, min, pi, sin;

import 'package:flutter/material.dart';

import '../models/diagram_data.dart';
import '../utils/constants.dart';

/// Computes the three triangle vertices in canvas space, guaranteed to
/// fit within `Rect.fromLTWH(0, 0, size.width, size.height)` regardless
/// of the angles — a tall/narrow or short/wide triangle is scaled to fit
/// **both** axes at once, never just width (the bug this replaced only
/// ever scaled against width, which let a tall triangle's apex land
/// above the available box). Laid out in unit space first (base length
/// 1) so the triangle's real aspect ratio can be measured before picking
/// a single scale factor.
///
/// A top-level, pure function (not a private method) specifically so a
/// test can assert the "always fits" guarantee directly against extreme
/// angle combinations, rather than only smoke-testing that painting
/// doesn't throw.
List<Offset> trianglePoints(
  List<double> angles,
  Size size, {
  required double padding,
}) {
  final a = angles[0] * pi / 180;
  final b = angles[1] * pi / 180;
  final c = angles[2] * pi / 180;

  final unitP0 = const Offset(0, 0);
  final unitP1 = const Offset(1, 0);
  final unitLenB = sin(b) / sin(c);
  final unitP2 = Offset(unitLenB * cos(a), -unitLenB * sin(a));

  final xs = [unitP0.dx, unitP1.dx, unitP2.dx];
  final ys = [unitP0.dy, unitP1.dy, unitP2.dy];
  final minX = xs.reduce(min);
  final shapeWidth = xs.reduce(max) - minX;
  final minY = ys.reduce(min);
  final shapeHeight = ys.reduce(max) - minY;

  final availableWidth = max(size.width - padding * 2, 10.0);
  final availableHeight = max(size.height - padding * 2, 10.0);
  final scale =
      min(availableWidth / shapeWidth, availableHeight / shapeHeight);

  Offset place(Offset unit) => Offset(
        padding + (unit.dx - minX) * scale,
        padding + (unit.dy - minY) * scale,
      );
  return [place(unitP0), place(unitP1), place(unitP2)];
}

/// Renders a [DiagramData] onto a [Canvas] — the "how do diagrams get
/// created quickly" answer for this project: plain `Canvas` primitives
/// (`drawPath`/`drawRect`/`drawCircle`/`drawOval`/`drawLine` plus
/// `TextPainter` for labels), no drawing/charting package. Each shape's
/// coordinates are derived from the puzzle's own generated numbers (see
/// e.g. `angle_finding_generator.dart`'s law-of-sines placement) — this
/// painter only lays them out on the canvas, it never invents a number.
///
/// Every shape below is deliberately laid out *within* `_padding` of every
/// edge of [size] — nothing here assumes a particular box size or aspect
/// ratio, since the diagram's actual on-screen box varies with the
/// device's width (see `game_screen.dart`'s `_buildOptionsWithDiagram`,
/// which also wraps this in a bordered frame + `ClipRect` as a hard
/// backstop, so even an edge case here can never visually escape the
/// frame — but the goal is a correctly-fitted diagram, not a clipped one).
class DiagramPainter extends CustomPainter {
  const DiagramPainter(this.data);

  final DiagramData data;

  /// Kept clear of every edge so labels (which extend a little past
  /// whatever vertex/bar/point they annotate) never sit flush against —
  /// or past — the frame around this painter.
  static const double _padding = 24;

  @override
  void paint(Canvas canvas, Size size) {
    switch (data.kind) {
      case DiagramKind.triangle:
        _paintTriangle(canvas, size);
      case DiagramKind.rectangle:
        _paintRectangle(canvas, size);
      case DiagramKind.circle:
        _paintCircle(canvas, size);
      case DiagramKind.cylinder:
        _paintCylinder(canvas, size);
      case DiagramKind.coordinatePoint:
        _paintCoordinatePoint(canvas, size);
      case DiagramKind.barGraph:
        _paintBarGraph(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant DiagramPainter oldDelegate) =>
      oldDelegate.data != data;

  Paint get _stroke => Paint()
    ..color = AppColors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  /// Places the three vertices via the law of sines from two known
  /// angles — the same placement `angle_finding_generator.dart`'s own
  /// doc comment describes. Laid out in *unit* space first (base length
  /// 1) so the triangle's real aspect ratio — which swings widely with
  /// the angles, from short-and-wide to tall-and-narrow — can be measured
  /// before deciding a single scale factor that fits it to **both**
  /// [size]'s width and height, never just one. That's what stops a
  /// tall triangle's apex from landing above the available box (the bug
  /// this replaced only ever scaled against width).
  void _paintTriangle(Canvas canvas, Size size) {
    final angles = data.angles!;
    final unknownIndex = data.unknownAngleIndex!;
    final points = trianglePoints(angles, size, padding: _padding);
    final p0 = points[0];
    final p1 = points[1];
    final p2 = points[2];

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, _stroke);

    final labels = List.generate(
      3,
      (i) => i == unknownIndex ? '?' : '${angles[i].round()}°',
    );
    _drawLabel(canvas, labels[0], p0 + const Offset(-8, 6));
    _drawLabel(canvas, labels[1], p1 + const Offset(-4, 6));
    _drawLabel(canvas, labels[2], p2 + const Offset(-8, -18));
  }

  void _paintRectangle(Canvas canvas, Size size) {
    final dims = data.dimensions!;
    final availableWidth = max(size.width - _padding * 2, 10.0);
    final availableHeight = max(size.height - _padding * 2, 10.0);
    // Fit to both axes at once (not width-then-derive-height) so a very
    // long/thin rectangle can't push past the top or bottom either.
    final scale = min(availableWidth / dims[0], availableHeight / dims[1]);
    final rectWidth = dims[0] * scale;
    final rectHeight = dims[1] * scale;
    final rect = Rect.fromLTWH(
      (size.width - rectWidth) / 2,
      (size.height - rectHeight) / 2,
      rectWidth,
      rectHeight,
    );
    canvas.drawRect(rect, _stroke);
    // Width label below, height label to the left — neither ever
    // approaches the right edge, which is where the old layout could
    // run off a narrow diagram box.
    _drawLabel(canvas, '${dims[0].round()} cm',
        Offset(rect.center.dx - 15, min(rect.bottom + 4, size.height - 16)));
    _drawLabel(canvas, '${dims[1].round()} cm',
        Offset(max(rect.left - 34, 0), rect.center.dy - 8));
  }

  void _paintCircle(Canvas canvas, Size size) {
    final radius = data.dimensions![0];
    final center = Offset(size.width / 2, size.height / 2);
    final displayRadius =
        max(size.shortestSide / 2 - _padding, 10.0);
    canvas.drawCircle(center, displayRadius, _stroke);
    canvas.drawLine(center, center + Offset(displayRadius, 0), _stroke);
    _drawLabel(canvas, '${radius.round()} cm',
        center + Offset(displayRadius / 2 - 12, -18));
  }

  void _paintCylinder(Canvas canvas, Size size) {
    final dims = data.dimensions!;
    final radius = dims[0];
    final height = dims[1];
    final availableWidth = max(size.width - _padding * 2, 10.0);
    final availableHeight = max(size.height - _padding * 2, 10.0);
    // The ellipse's own height eats into the vertical budget too — solve
    // for a displayWidth where ellipseHeight (0.3x) + bodyHeight (0.5x
    // display width, scaled) together still fit availableHeight.
    final displayWidth =
        min(availableWidth, availableHeight / 0.8).clamp(10.0, availableWidth);
    final ellipseHeight = displayWidth * 0.3;
    final bodyHeight = displayWidth * 0.5;
    final left = (size.width - displayWidth) / 2;
    final top = (size.height - (bodyHeight + ellipseHeight)) / 2;

    final topRect = Rect.fromLTWH(left, top, displayWidth, ellipseHeight);
    final bottomRect =
        Rect.fromLTWH(left, top + bodyHeight, displayWidth, ellipseHeight);
    canvas.drawOval(topRect, _stroke);
    canvas.drawLine(Offset(left, top + ellipseHeight / 2),
        Offset(left, top + bodyHeight + ellipseHeight / 2), _stroke);
    canvas.drawLine(
        Offset(left + displayWidth, top + ellipseHeight / 2),
        Offset(left + displayWidth, top + bodyHeight + ellipseHeight / 2),
        _stroke);
    canvas.drawArc(bottomRect, 0, pi, false, _stroke);

    // Radius label above, height label to the left — mirrors the
    // rectangle's fix, keeping both clear of the right edge.
    _drawLabel(canvas, '${radius.round()} cm',
        Offset(left + displayWidth / 2 - 12, max(top - 18, 0)));
    _drawLabel(canvas, '${height.round()} cm',
        Offset(max(left - 34, 0), top + bodyHeight / 2 - 6));
  }

  void _paintCoordinatePoint(Canvas canvas, Size size) {
    final x = data.x!;
    final y = data.y!;
    final origin = Offset(_padding + 8, size.height - _padding);
    final axisSpanX = max(size.width - origin.dx - _padding, 10.0);
    final axisSpanY = max(origin.dy - _padding, 10.0);
    // Scaled against *both* axes (the old version only used width),
    // which is what could previously push the point above the canvas
    // for a tall, narrow diagram box.
    final scale = min(axisSpanX / (x * 1.3), axisSpanY / (y * 1.3));

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.5;
    canvas.drawLine(origin, Offset(origin.dx, _padding), axisPaint);
    canvas.drawLine(
        origin, Offset(size.width - _padding, origin.dy), axisPaint);

    final point = Offset(origin.dx + x * scale, origin.dy - y * scale);
    canvas.drawLine(origin, point, _stroke);
    canvas.drawCircle(point, 5, Paint()..color = AppColors.wrong);

    _drawLabel(canvas, '(${x.round()}, ${y.round()})',
        Offset(min(point.dx + 8, size.width - 60), max(point.dy - 18, 0)));
    _drawLabel(canvas, 'O', origin + const Offset(-14, 2));
  }

  void _paintBarGraph(Canvas canvas, Size size) {
    final categories = data.categories!;
    final values = data.values!;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    // Leaves room above (value labels) and below (category labels) the
    // bars themselves, within the shared padding budget.
    final baseline = size.height - _padding;
    final barAreaHeight = max(baseline - _padding - 18, 10.0);
    final gap = 8.0;
    final barWidth = max(
      (size.width - _padding * 2 - gap * (categories.length + 1)) /
          categories.length,
      4.0,
    );

    for (var i = 0; i < categories.length; i++) {
      final barHeight = values[i] / maxValue * barAreaHeight;
      final left = _padding + gap + i * (barWidth + gap);
      final rect =
          Rect.fromLTWH(left, baseline - barHeight, barWidth, barHeight);
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.tierAccents[i % AppColors.tierAccents.length],
      );
      _drawLabel(canvas, '${values[i]}',
          Offset(left + barWidth / 2 - 8, max(baseline - barHeight - 18, 0)));
      _drawLabel(
          canvas, categories[i], Offset(left + barWidth / 2 - 4, baseline + 4));
    }
    canvas.drawLine(Offset(_padding, baseline),
        Offset(size.width - _padding, baseline),
        Paint()..color = Colors.black54..strokeWidth = 1.5);
  }
}
