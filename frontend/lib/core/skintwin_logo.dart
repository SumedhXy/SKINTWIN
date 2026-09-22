import 'package:flutter/material.dart';
import 'theme.dart';

class SkinTwinLogo extends StatelessWidget {
  final double size;
  final bool isDark;

  const SkinTwinLogo({
    super.key,
    this.size = 32,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: isDark
            ? AppTheme.darkHeroGradient
            : const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isDark ? Colors.white24 : AppTheme.primaryBlue.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: SkinTwinLogoPainter(isDark: isDark),
      ),
    );
  }
}

class SkinTwinLogoPainter extends CustomPainter {
  final bool isDark;

  SkinTwinLogoPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.22;

    // 1. Left Twin Ring
    final leftCenter = center - Offset(size.width * 0.11, 0);
    final ringPaint1 = Paint()
      ..shader = AppTheme.primaryGradient.createShader(Rect.fromCircle(center: leftCenter, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(leftCenter, radius, ringPaint1);

    // 2. Right Twin Ring (Interlocking)
    final rightCenter = center + Offset(size.width * 0.11, 0);
    final ringPaint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromCircle(center: rightCenter, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(rightCenter, radius, ringPaint2);

    // 3. Center Precision Target Reticle Dot
    final dotPaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(center, size.width * 0.06, dotPaint);

    final dotGlow = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, size.width * 0.09, dotGlow);

    // 4. Subtle Crosshair lines
    final crosshairPaint = Paint()
      ..color = isDark ? Colors.white70 : AppTheme.primaryBlue
      ..strokeWidth = 1.2;

    final chLen = size.width * 0.08;
    canvas.drawLine(center - Offset(chLen, 0), center - Offset(chLen * 0.4, 0), crosshairPaint);
    canvas.drawLine(center + Offset(chLen * 0.4, 0), center + Offset(chLen, 0), crosshairPaint);
    canvas.drawLine(center - Offset(0, chLen), center - Offset(0, chLen * 0.4), crosshairPaint);
    canvas.drawLine(center + Offset(0, chLen * 0.4), center + Offset(0, chLen), crosshairPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
