import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Overlay frame 4:3 dengan corner bracket di atas preview kamera.
///
/// Semua ukuran dihitung relatif terhadap kotak yang diberikan, sehingga
/// painter ini aman dipakai di dalam card preview (bukan hanya fullscreen).
class CameraOverlayPainter extends CustomPainter {
  const CameraOverlayPainter({
    this.frameAspectRatio = 4 / 3,
    this.horizontalInsetFactor = 0.07,
  });

  /// Rasio lebar:tinggi area pindai.
  final double frameAspectRatio;

  /// Jarak kiri/kanan frame dari tepi widget (0.07 = 7%).
  final double horizontalInsetFactor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final maxFrameWidth = size.width * (1 - horizontalInsetFactor * 2);
    final maxFrameHeight = size.height * 0.64;
    final frameHeight =
        math.min(maxFrameWidth / frameAspectRatio, maxFrameHeight);
    final frameWidth = frameHeight * frameAspectRatio;

    final rect = Rect.fromLTWH(
      (size.width - frameWidth) / 2,
      (size.height - frameHeight) / 2,
      frameWidth,
      frameHeight,
    );

    // Redupkan area di luar frame.
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.32);
    final dimPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, dimPaint);

    // Garis bantu horizontal tipis di tengah frame.
    final scanLinePaint = Paint()
      ..color = AppColors.primarySage.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      scanLinePaint,
    );

    final cornerPaint = Paint()
      ..color = AppColors.primarySage
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength =
        math.min(28.0, math.min(rect.width, rect.height) * 0.18);

    _drawCorner(canvas, cornerPaint, rect.topLeft, cornerLength, 1, 1);
    _drawCorner(canvas, cornerPaint, rect.topRight, cornerLength, -1, 1);
    _drawCorner(canvas, cornerPaint, rect.bottomLeft, cornerLength, 1, -1);
    _drawCorner(canvas, cornerPaint, rect.bottomRight, cornerLength, -1, -1);
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset origin,
    double length,
    double dx,
    double dy,
  ) {
    canvas.drawLine(origin, origin.translate(dx * length, 0), paint);
    canvas.drawLine(origin, origin.translate(0, dy * length), paint);
  }

  @override
  bool shouldRepaint(covariant CameraOverlayPainter oldDelegate) {
    return oldDelegate.frameAspectRatio != frameAspectRatio ||
        oldDelegate.horizontalInsetFactor != horizontalInsetFactor;
  }
}
