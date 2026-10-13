import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// Custom painter untuk overlay frame kamera 4:3
// Menggambar corner brackets sebagai target area pindai INCI
class CameraOverlayPainter extends CustomPainter {
  CameraOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double frameW = size.width * 0.80;
    final double frameH = frameW * (4 / 3);
    final double left = (size.width - frameW) / 2;
    final double top = (size.height - frameH) / 2 - 40;
    final double right = left + frameW;
    final double bottom = top + frameH;
    const double cornerLength = 28;
    const double cornerRadius = 4;
    const double strokeWidth = 2.5;

    final paint = Paint()
      ..color = AppColors.primarySage
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dim overlay outside the frame
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(cornerRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // Draw corner brackets
    _drawCorner(canvas, paint, left, top, cornerLength, 1, 1);
    _drawCorner(canvas, paint, right, top, cornerLength, -1, 1);
    _drawCorner(canvas, paint, left, bottom, cornerLength, 1, -1);
    _drawCorner(canvas, paint, right, bottom, cornerLength, -1, -1);
  }

  void _drawCorner(Canvas canvas, Paint paint, double x, double y,
      double len, double dx, double dy) {
    canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
