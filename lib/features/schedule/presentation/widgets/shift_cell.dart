import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/schedule/presentation/widgets/schedule_helpers.dart';

/// One shift slot in the weekly grid — a tappable cell that shows **who** is on
/// the shift (faces + names), not just a number. A staffed slot reads as a
/// premium elevated card with an avatar stack; an empty slot is a muted,
/// dashed placeholder ("No one"); today's column gets a white ring; a broken
/// reference is flagged. Strictly monochrome — no staffing target/quota is ever
/// implied, the admin assigns by judgment.
class ShiftCell extends StatelessWidget {
  const ShiftCell({
    super.key,
    required this.users,
    required this.isToday,
    required this.hasOrphan,
    required this.width,
    required this.height,
    required this.onTap,
  });

  /// The currently-assigned (resolvable) employees on this slot.
  final List<UserEntity> users;
  final bool isToday;
  final bool hasOrphan;
  final double width;
  final double height;
  final VoidCallback onTap;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final empty = users.isEmpty;
    final dashed = empty && !isToday;
    final content = empty ? _empty() : _staffed();

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            child: dashed
                ? CustomPaint(
                    painter: _DashedBorderPainter(
                        color: AppColors.darkBorder, radius: _radius),
                    child: content,
                  )
                : Ink(
                    decoration: BoxDecoration(
                      // Staffed slots get a subtle top-lit sheen; empty-but-today
                      // stays flat with just the ring.
                      gradient: empty
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.darkSurfaceElevated,
                                AppColors.darkSurface,
                              ],
                            ),
                      color: empty ? AppColors.darkBg : null,
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(
                        color: isToday
                            ? AppColors.primary.withAlpha(160)
                            : AppColors.darkBorder,
                        width: isToday ? 1.4 : 1,
                      ),
                    ),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _staffed() {
    final names = users.take(2).toList();
    final extra = users.length - names.length;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarStack(users: users, max: 3, size: 26),
              const SizedBox(height: 9),
              for (var i = 0; i < names.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
                  child: Text(
                    shortName(names[i]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: i == 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                ),
              if (extra > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('+$extra more',
                      style: AppTypography.caption.copyWith(height: 1)),
                ),
            ],
          ),
        ),
        if (hasOrphan)
          const Positioned(
            top: 6,
            right: 6,
            child: Icon(Icons.warning_amber_rounded,
                size: 13, color: AppColors.warning),
          ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_alt_1_outlined,
              size: 22, color: AppColors.textTertiary),
          const SizedBox(height: 7),
          Text('No one',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

/// Draws a rounded-rect **dashed** outline — the premium "empty slot" cue, so an
/// unstaffed shift reads as an open placeholder rather than a filled card.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + _dash;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0, metric.length)),
          paint,
        );
        dist = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
