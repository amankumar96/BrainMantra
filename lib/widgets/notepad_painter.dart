import 'package:flutter/material.dart';

import '../models/notepad_stroke.dart';

/// Paints the scratch notepad's faint graph-paper gridlines, then every
/// stroke on top in ink — same `CustomPainter` technique
/// `diagram_painter.dart` already uses for rendered question diagrams.
class NotepadPainter extends CustomPainter {
  const NotepadPainter(this.strokes);

  final List<NotepadStroke> strokes;

  /// Low-contrast on purpose — a visual grid to write against, not a
  /// pattern competing with the player's own ink.
  static const double gridSpacing = 24;
  static const Color gridColor = Color(0x14000000); // ~8% black
  static const Color inkColor = Color(0xFF1A2233); // AppColors.submitButtonText

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final inkPaint = Paint()
      ..color = inkColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  // Always repaints — drawing is cheap, and strokes are mutated in place
  // as the player draws (new points appended to the last stroke), so a
  // value-equality or identity check here would be unreliable; simple
  // correctness over a micro-optimization for a low-frequency canvas.
  @override
  bool shouldRepaint(covariant NotepadPainter oldDelegate) => true;
}
