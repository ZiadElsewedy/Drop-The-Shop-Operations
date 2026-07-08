import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/animated_count.dart';
import 'package:drop/core/widgets/glass_container.dart';

/// **AttentionTile** — a priority triage cell for the "Needs Attention" layer
/// (DROP Design System V2). A soft-accent glyph, a big live [count], and a
/// label; tapping it opens the filtered view for that signal. This is the
/// generalisation of the old bespoke dashboard pending-action pills, built to be
/// reused by any module (tasks pending review, requests awaiting a decision,
/// active cases, …).
///
/// Calm by construction: it stays monochrome when the count is **zero** and only
/// picks up its semantic [accent] on the number/glyph when there is real work to
/// do — so a quiet dashboard reads quiet.
///
/// The tile is a pure core widget (the [borderRadius] matches its surface) so a
/// feature that wants the single most-urgent tile to carry the living-border
/// orbit can wrap it in `LiveStatusBorder(borderRadius: AttentionTile.radius, …)`
/// without this primitive depending on the task feature.
///
/// Accessibility: a [Semantics] button label ("N label"), a ≥44px tap target,
/// and it honours reduced-motion (`MediaQuery.disableAnimations`) by dropping the
/// count-up tween.
class AttentionTile extends StatelessWidget {
  const AttentionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.sublabel,
    this.accent,
  });

  /// The tile's corner radius — exposed so a caller can match a wrapping
  /// `LiveStatusBorder` to the surface.
  static const BorderRadius radius = AppRadius.cardAll;

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  /// Optional second line under the label (e.g. "Past the deadline").
  final String? sublabel;

  /// Semantic tint applied to the glyph + number **only when [count] > 0**
  /// (default [AppColors.warning]). Null falls back to warning.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final active = count > 0;
    final tint = accent ?? AppColors.warning;
    final glyphTint = active ? tint : AppColors.textTertiary;

    return Semantics(
      button: true,
      label: '$count $label',
      child: GlassContainer(
        onTap: onTap,
        highlight: active,
        accent: tint,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: glyphTint.withAlpha(active ? 30 : 20),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: glyphTint),
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedCount(
                value: count,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                style: AppTypography.h1.copyWith(
                  fontSize: 30,
                  color:
                      active ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 1),
                Text(
                  sublabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
