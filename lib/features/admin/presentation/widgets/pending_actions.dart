import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/glass_container.dart';

/// Admin Home **Pending Actions** panel (spec §1) — a consolidated, actionable
/// queue of everything waiting on the admin: shift-swap requests, employee
/// approvals, tasks waiting review, and overdue tasks. Each non-empty queue is a
/// tappable row that jumps straight to where it's resolved.
///
/// Presentational only (counts + callbacks) so it renders in widget tests with no
/// cubits/router. **Always rendered** by the dashboard — when everything is clear
/// it shows an explicit "all caught up" state rather than vanishing (the earlier
/// `if (count > 0)` gate made the section look like it didn't exist).
class PendingActions extends StatelessWidget {
  const PendingActions({
    super.key,
    required this.swaps,
    required this.approvals,
    required this.reviews,
    required this.overdue,
    required this.onSwaps,
    required this.onApprovals,
    required this.onReviews,
    required this.onOverdue,
  });

  final int swaps;
  final int approvals;
  final int reviews;
  final int overdue;
  final VoidCallback onSwaps;
  final VoidCallback onApprovals;
  final VoidCallback onReviews;
  final VoidCallback onOverdue;

  /// Total items needing attention — also drives the section subtitle.
  int get total => swaps + approvals + reviews + overdue;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (swaps > 0)
        _ActionRow(
          icon: Icons.swap_horiz_rounded,
          label: swaps == 1 ? '1 Swap Request' : '$swaps Swap Requests',
          detail: 'Review shift swaps',
          accent: AppColors.warning,
          onTap: onSwaps,
        ),
      if (approvals > 0)
        _ActionRow(
          icon: Icons.how_to_reg_rounded,
          label: approvals == 1
              ? '1 Employee Approval'
              : '$approvals Employee Approvals',
          detail: 'Approve new accounts',
          accent: AppColors.warning,
          onTap: onApprovals,
        ),
      if (reviews > 0)
        _ActionRow(
          icon: Icons.rate_review_rounded,
          label: reviews == 1
              ? '1 Task Waiting Review'
              : '$reviews Tasks Waiting Review',
          detail: 'Approve or send back',
          accent: AppColors.warning,
          onTap: onReviews,
        ),
      if (overdue > 0)
        _ActionRow(
          icon: Icons.warning_amber_rounded,
          label: overdue == 1 ? '1 Overdue Task' : '$overdue Overdue Tasks',
          detail: 'Past the deadline',
          accent: AppColors.error,
          onTap: onOverdue,
        ),
    ];

    if (rows.isEmpty) {
      // All clear — keep the panel visible so the admin knows it's here.
      return GlassContainer(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(28),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're all caught up", style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text('No swaps, approvals, reviews or overdue tasks.',
                      style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(color: AppColors.darkBorder, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(detail, style: AppTypography.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
