import 'package:flutter/material.dart';

/// A few soft, semi-transparent white wave curves low in a gradient
/// header — purely decorative, meant to be painted behind that header's
/// real content. Shared by [HomeScreen]'s and [LoginScreen]'s banners so
/// both carry the same visual identity (see `Documents/` for the mockup
/// this was pixel-matched to).
class HeaderWavePainter extends CustomPainter {
  const HeaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    void drawWave(double baseline, double amplitude, double opacity) {
      final path = Path()..moveTo(-20, baseline);
      path.quadraticBezierTo(
        size.width * 0.25,
        baseline - amplitude,
        size.width * 0.5,
        baseline,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        baseline + amplitude,
        size.width + 20,
        baseline,
      );
      path.lineTo(size.width + 20, size.height + 20);
      path.lineTo(-20, size.height + 20);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    drawWave(size.height * 0.72, 14, 0.06);
    drawWave(size.height * 0.85, 10, 0.05);
  }

  @override
  bool shouldRepaint(covariant HeaderWavePainter oldDelegate) => false;
}
