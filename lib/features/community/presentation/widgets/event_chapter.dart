import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';

/// The shared **chapter** kit for the event workspace. Each operational section
/// (Timeline, Team, Tasks, …) renders as a chapter with an eyebrow, a title, an
/// optional count + trailing action, and generous breathing room — so scrolling
/// the workspace reveals the event as a story rather than a stack of identical
/// cards.

/// A section header + body with rhythm. [eyebrow] is the small uppercase kicker
/// ("TIMELINE"); [action] is an optional trailing control (usually an add button).
class EventChapter extends StatelessWidget {
  const EventChapter({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.icon,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        eyebrow.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(title, style: AppTypography.h2),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: AppTypography.bodySmall),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.md),
              action!,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

/// A thin monochrome progress bar with a smooth grow — used by sections for
/// "X of Y done".
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.height = 6,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.darkBorder),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v == 0 ? 0.0001 : v,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withAlpha(160), color],
                  ),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A checkable row (task / milestone / inventory / logistics). A tappable check
/// disc on the left, a title (struck through when done), optional [subtitle] and
/// [trailing], and an optional long-press for a context action (delete).
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.done,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leadingTint,
    this.onToggle,
    this.onLongPress,
    this.enabled = true,
  });

  final bool done;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? leadingTint;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tint = leadingTint ?? AppColors.success;
    return InkWell(
      onTap: enabled ? onToggle : null,
      onLongPress: enabled ? onLongPress : null,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2, horizontal: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CheckDisc(done: done, tint: tint),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.label.copyWith(
                      color: done
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckDisc extends StatelessWidget {
  const _CheckDisc({required this.done, required this.tint});
  final bool done;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? tint.withAlpha(38) : AppColors.transparent,
        border: Border.all(
          color: done ? tint : AppColors.textTertiary,
          width: 1.6,
        ),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 14, color: tint)
          : const SizedBox.shrink(),
    );
  }
}

/// A quiet dashed "add …" affordance closing a section (matches the create
/// sheet's checklist builder language).
class AddRow extends StatelessWidget {
  const AddRow({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(label,
                style: AppTypography.label
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// A quiet empty state inside a chapter (no full-screen brand mark).
class SectionEmpty extends StatelessWidget {
  const SectionEmpty({super.key, required this.message, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

/// The compact "＋" pill used as a chapter's trailing action.
class ChapterAddButton extends StatelessWidget {
  const ChapterAddButton({super.key, required this.onTap, this.tooltip});
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fullAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.fullAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: AppColors.textPrimary),
            SizedBox(width: 4),
            Text('Add', style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
