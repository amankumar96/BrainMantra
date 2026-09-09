import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../models/diagram_data.dart';
import '../utils/constants.dart';

/// Renders a [DiagramData] onto a [Canvas] — the "how do diagrams get
/// created quickly" answer for this project: plain `Canvas` primitives
/// (`drawPath`/`drawRect`/`drawCircle`/`drawOval`/`drawLine` plus
/// `TextPainter` for labels), no drawing/charting package. Each shape's
/// coordinates are derived from the puzzle's own generated numbers (see
/// e.g. `angle_finding_generator.dart`'s law-of-sines placement) — this
/// painter only lays them out on the canvas, it never invents a number.
class DiagramPainter extends CustomPainter {
  const DiagramPainter(this.data);

  final DiagramData data;

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
  /// doc comment describes: base along the x-axis, third vertex derived
  /// from angle A and the base/angle-C ratio.
  void _paintTriangle(Canvas canvas, Size size) {
    final angles = data.angles!;
    final unknownIndex = data.unknownAngleIndex!;
    final a = angles[0] * pi / 180;
    final b = angles[1] * pi / 180;
    final c = angles[2] * pi / 180;

    final base = size.width * 0.75;
    final p0 = Offset(size.width * 0.1, size.height * 0.8);
    final p1 = Offset(p0.dx + base, p0.dy);
    final lenB = base * sin(b) / sin(c);
    final p2 = Offset(p0.dx + lenB * cos(a), p0.dy - lenB * sin(a));

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
    _drawLabel(canvas, labels[2], p2 + const Offset(-8, -22));
  }

  void _paintRectangle(Canvas canvas, Size size) {
    final dims = data.dimensions!;
    final rectWidth = size.width * 0.7;
    final rectHeight =
        (rectWidth * (dims[1] / dims[0])).clamp(20.0, size.height * 0.6);
    final rect = Rect.fromLTWH(
      (size.width - rectWidth) / 2,
      (size.height - rectHeight) / 2,
      rectWidth,
      rectHeight,
    );
    canvas.drawRect(rect, _stroke);
    _drawLabel(canvas, '${dims[0].round()} cm',
        Offset(rect.center.dx - 15, rect.bottom + 4));
    _drawLabel(canvas, '${dims[1].round()} cm',
        Offset(rect.right + 4, rect.center.dy - 8));
  }

  void _paintCircle(Canvas canvas, Size size) {
    final radius = data.dimensions![0];
    final center = Offset(size.width / 2, size.height / 2);
    final displayRadius = size.shortestSide / 2 * 0.7;
    canvas.drawCircle(center, displayRadius, _stroke);
    canvas.drawLine(center, center + Offset(displayRadius, 0), _stroke);
    _drawLabel(canvas, '${radius.round()} cm',
        center + Offset(displayRadius / 2 - 12, -18));
  }

  void _paintCylinder(Canvas canvas, Size size) {
    final dims = data.dimensions!;
    final radius = dims[0];
    final height = dims[1];
    final displayWidth = size.width * 0.5;
    final ellipseHeight = displayWidth * 0.3;
    final bodyHeight = size.height * 0.5;
    final left = (size.width - displayWidth) / 2;
    final top = size.height * 0.15;

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

    _drawLabel(canvas, '${radius.round()} cm',
        Offset(left + displayWidth / 2 - 12, top - 18));
    _drawLabel(canvas, '${height.round()} cm',
        Offset(left + displayWidth + 4, top + bodyHeight / 2 - 6));
  }

  void _paintCoordinatePoint(Canvas canvas, Size size) {
    final x = data.x!;
    final y = data.y!;
    final origin = Offset(size.width * 0.15, size.height * 0.85);
    final maxAxis = x > y ? x : y;
    final scale = (size.width * 0.7) / (maxAxis * 1.3);

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.5;
    canvas.drawLine(
        origin, Offset(origin.dx, origin.dy - size.height * 0.7), axisPaint);
    canvas.drawLine(
        origin, Offset(origin.dx + size.width * 0.75, origin.dy), axisPaint);

    final point = Offset(origin.dx + x * scale, origin.dy - y * scale);
    canvas.drawLine(origin, point, _stroke);
    canvas.drawCircle(point, 5, Paint()..color = AppColors.wrong);

    _drawLabel(canvas, '(${x.round()}, ${y.round()})', point + const Offset(8, -18));
    _drawLabel(canvas, 'O', origin + const Offset(-14, 2));
  }

  void _paintBarGraph(Canvas canvas, Size size) {
    final categories = data.categories!;
    final values = data.values!;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final barAreaHeight = size.height * 0.65;
    final baseline = size.height * 0.85;
    final gap = 8.0;
    final barWidth = (size.width - gap * (categories.length + 1)) /
        categories.length;

    for (var i = 0; i < categories.length; i++) {
      final barHeight = values[i] / maxValue * barAreaHeight;
      final left = gap + i * (barWidth + gap);
      final rect =
          Rect.fromLTWH(left, baseline - barHeight, barWidth, barHeight);
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.tierAccents[i % AppColors.tierAccents.length],
      );
      _drawLabel(canvas, '${values[i]}', Offset(left + barWidth / 2 - 8,
          baseline - barHeight - 18));
      _drawLabel(
          canvas, categories[i], Offset(left + barWidth / 2 - 4, baseline + 4));
    }
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline),
        Paint()..color = Colors.black54..strokeWidth = 1.5);
  }
}
