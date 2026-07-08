import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';

/// A circular **preparation ring** — the single visual for "how ready is this?".
/// It animates smoothly to [progress] (0..1) whenever the value changes, so real
/// work visibly grows the ring. Used large in the event hero and small on hub
/// cards. Strictly monochrome track with a soft accent sweep.
class PreparationRing extends StatelessWidget {
  const PreparationRing({
    super.key,
    required this.progress,
    this.size = 96,
    this.stroke = 8,
    this.color = AppColors.primary,
    this.label,
    this.centerBuilder,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color color;

  /// Optional caption under the percentage (e.g. "ready").
  final String? label;

  /// Overrides the centre content (defaults to the percent + [label]).
  final WidgetBuilder? centerBuilder;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value: value, stroke: stroke, color: color),
          child: Center(
            child: centerBuilder?.call(context) ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(value * 100).round()}%',
                      style: AppTypography.h3.copyWith(
                        fontSize: size * 0.24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (label != null)
                      Text(
                        label!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: size * 0.11,
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.stroke, required this.color});

  final double value;
  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.darkBorder;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (value <= 0) return;

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withAlpha(150), color],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, sweep);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}
