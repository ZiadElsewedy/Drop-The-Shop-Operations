import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';

/// The DROP wordmark — a bold, outlined "DROP" with the signature downward
/// arrow descending from the right (the brand's "drop"). Monochrome and
/// asset-free, so it scales and themes (white on the dark UI) anywhere.
///
/// Used app-wide: splash/loading, the auth screens, and the pending-approval
/// screen. Size it with [fontSize]; override [color] for non-default contexts.
class DropLogo extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const DropLogo({super.key, this.fontSize = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;

    return SizedBox(
      height: fontSize * 1.85,
      width: fontSize * 3.5,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Outlined "DROP" wordmark.
          Text(
            'DROP',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: fontSize * 0.02,
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.045
                ..strokeJoin = StrokeJoin.round
                ..color = c,
            ),
          ),
          // Downward arrow dropping from under the "P".
          Positioned(
            bottom: 0,
            right: fontSize * 0.42,
            child: CustomPaint(
              size: Size(fontSize * 0.62, fontSize * 1.08),
              painter: _DropArrowPainter(c, fontSize * 0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropArrowPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DropArrowPainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final shaftHalf = w * 0.16;
    final wingHalf = w * 0.5 - strokeWidth;
    final shoulderY = h * 0.52;

    // Hollow arrow silhouette (shaft + arrowhead), stroked to match the
    // outlined wordmark.
    final path = Path()
      ..moveTo(cx - shaftHalf, strokeWidth)
      ..lineTo(cx + shaftHalf, strokeWidth)
      ..lineTo(cx + shaftHalf, shoulderY)
      ..lineTo(cx + wingHalf, shoulderY)
      ..lineTo(cx, h - strokeWidth)
      ..lineTo(cx - wingHalf, shoulderY)
      ..lineTo(cx - shaftHalf, shoulderY)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DropArrowPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
