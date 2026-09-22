import 'dart:math';
import 'package:flutter/material.dart';

class SkinSpotPainter extends CustomPainter {
  final Color spotColor;
  final String label;
  final bool showGrid;
  final bool showReticle;
  final double scanProgress;

  SkinSpotPainter({
    required this.spotColor,
    required this.label,
    this.showGrid = true,
    this.showReticle = true,
    this.scanProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base Skin Texture Canvas
    final bgPaint = Paint()..color = const Color(0xFFF5D6C6);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), bgPaint);

    // 2. Micro Dermoscopic Texture Noise
    final rand = Random(label.hashCode);
    final texturePaint = Paint()..color = const Color(0xFF8D5B4C).withValues(alpha: 0.07);
    for (int i = 0; i < 45; i++) {
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
        rand.nextDouble() * 2.5 + 0.5,
        texturePaint,
      );
    }

    // 3. Main Lesion / Skin Finding Polygon
    final spotCenter = Offset(size.width * 0.5, size.height * 0.48);
    final spotPaint = Paint()
      ..color = spotColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final path = Path();
    path.addOval(Rect.fromCenter(center: spotCenter, width: size.width * 0.32, height: size.height * 0.36));
    canvas.drawPath(path, spotPaint);

    // 4. Pigment Core Density Layer
    final corePaint = Paint()
      ..color = spotColor.withValues(alpha: 0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawCircle(spotCenter, size.width * 0.11, corePaint);

    // 5. Photogrammetry Metric Grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 1;
      
      const step = 16.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // Millimeter Scale Ruler Marks at Bottom Edge
      final rulerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (double x = 12; x < size.width - 12; x += 6) {
        final tickHeight = (x % 30 == 0) ? 6.0 : 3.0;
        canvas.drawLine(Offset(x, size.height - tickHeight - 4), Offset(x, size.height - 4), rulerPaint);
      }
    }

    // 6. Reticle Brackets & Alignment Target
    if (showReticle) {
      final reticlePaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      
      canvas.drawCircle(spotCenter, size.width * 0.38, reticlePaint);

      // Target Brackets
      const bLen = 8.0;
      final bracketPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2;

      const offset = 22.0;
      // Top Left
      canvas.drawLine(spotCenter + const Offset(-offset, -offset), spotCenter + const Offset(-offset + bLen, -offset), bracketPaint);
      canvas.drawLine(spotCenter + const Offset(-offset, -offset), spotCenter + const Offset(-offset, -offset + bLen), bracketPaint);

      // Top Right
      canvas.drawLine(spotCenter + const Offset(offset, -offset), spotCenter + const Offset(offset - bLen, -offset), bracketPaint);
      canvas.drawLine(spotCenter + const Offset(offset, -offset), spotCenter + const Offset(offset, -offset + bLen), bracketPaint);

      // Bottom Left
      canvas.drawLine(spotCenter + const Offset(-offset, offset), spotCenter + const Offset(-offset + bLen, offset), bracketPaint);
      canvas.drawLine(spotCenter + const Offset(-offset, offset), spotCenter + const Offset(-offset, offset - bLen), bracketPaint);

      // Bottom Right
      canvas.drawLine(spotCenter + const Offset(offset, offset), spotCenter + const Offset(offset - bLen, offset), bracketPaint);
      canvas.drawLine(spotCenter + const Offset(offset, offset), spotCenter + const Offset(offset, offset - bLen), bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
