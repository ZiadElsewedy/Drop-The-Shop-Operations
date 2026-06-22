import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';

/// One shift slot in the weekly grid — a tappable cell showing **how many
/// employees are assigned** (not a quota). The schedule represents assignments,
/// so the cell is a monochrome density tile: the more people on a shift, the
/// brighter it reads; an empty shift is shown distinctly (a muted "—"), a broken
/// reference is flagged, and today's column gets a white ring. No required /
/// target staffing is implied — the admin assigns by judgment.
class ShiftCell extends StatelessWidget {
  const ShiftCell({
    super.key,
    required this.count,
    required this.isToday,
    required this.hasOrphan,
    required this.width,
    required this.height,
    required this.onTap,
  });

  /// Number of currently-assigned (resolvable) employees on this slot.
  final int count;
  final bool isToday;
  final bool hasOrphan;
  final double width;
  final double height;
  final VoidCallback onTap;

  /// Monochrome density wash — empty stays flat; each extra person adds a little
  /// white, capped so a busy shift reads brightest. Purely a visual heat cue for
  /// assignment density, never a target.
  int get _tintAlpha => count <= 0 ? 0 : (8 + (count.clamp(1, 4) * 9));

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: empty
                    ? AppColors.darkBg
                    : AppColors.white.withAlpha(_tintAlpha),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isToday
                      ? AppColors.primary.withAlpha(150)
                      : AppColors.darkBorder,
                  width: isToday ? 1.4 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: empty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('—',
                                  style: AppTypography.h3.copyWith(
                                    color: AppColors.textTertiary,
                                    height: 1,
                                  )),
                              const SizedBox(height: 2),
                              Text('Empty',
                                  style:
                                      AppTypography.caption.copyWith(height: 1)),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$count',
                                  style: AppTypography.h2.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  )),
                              const SizedBox(height: 2),
                              Text(count == 1 ? 'person' : 'people',
                                  style:
                                      AppTypography.caption.copyWith(height: 1)),
                            ],
                          ),
                  ),
                  if (hasOrphan)
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(Icons.warning_amber_rounded,
                          size: 13, color: AppColors.warning),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
