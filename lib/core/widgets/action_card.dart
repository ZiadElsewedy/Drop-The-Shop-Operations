import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/glass_container.dart';

/// A premium quick-action tile — an icon in a rounded chip with a title and an
/// optional subtitle. Replaces boring [ListTile]s for the admin's primary
/// actions (Add Branch, Assign Task, …). Built on [GlassContainer] so it shares
/// the press feedback and depth of every other card.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Icon tint (defaults to the white accent).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withAlpha(28),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: tint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
