import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// Circular Match Score Gauge Widget
/// Sesuai PRD Section 2D: Radial gauge besar dengan persentase di tengah
class CircularMatchScore extends StatelessWidget {
  const CircularMatchScore({
    super.key,
    required this.score,
    this.size = 88,
  });

  final int score; // 0–100
  final double size;

  Color get _scoreColor {
    if (score >= 80) return AppColors.statusSafe;
    if (score >= 60) return AppColors.statusWarning;
    return AppColors.statusDanger;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreArcPainter(score: score, color: _scoreColor),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score%',
                style: AppTypography.scoreDisplay.copyWith(
                  color: _scoreColor,
                  fontSize: size * 0.26,
                ),
              ),
              Text(
                'MATCH',
                style: AppTypography.scoreLabel.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: size * 0.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  const _ScoreArcPainter({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 7.0;
    const startAngle = -math.pi * 0.8;
    const sweepTotal = math.pi * 1.6;

    // Background track
    final bgPaint = Paint()
      ..color = AppColors.borderLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = sweepTotal * (score / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter oldDelegate) =>
      oldDelegate.score != score;
}
