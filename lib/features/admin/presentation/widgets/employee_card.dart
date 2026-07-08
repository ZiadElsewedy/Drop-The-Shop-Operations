import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/admin/presentation/employee_metrics.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

/// Premium, information-dense employee card for the admin Employees page.
/// Identity (avatar · name · role · branch), work status (active/inactive), and
/// a performance metric strip (Completed · Pending · Completion rate · Late) so
/// an admin understands an employee without opening details. Actions are
/// supplied by the screen and shown under a divider.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.user,
    this.metrics = const EmployeeMetrics(),
    this.branchLabel,
    this.onTap,
    this.actions = const [],
  });

  final UserEntity user;
  final EmployeeMetrics metrics;
  final String? branchLabel;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : user.email;
    final hasBranch = (branchLabel != null && branchLabel!.isNotEmpty) ||
        (user.branchId != null && user.branchId!.isNotEmpty);
    final branch = (branchLabel != null && branchLabel!.isNotEmpty)
        ? branchLabel!
        : (user.branchId ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassContainer(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Identity ──────────────────────────────────────────
            Row(
              children: [
                UserAvatar.fromUser(user, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            _capitalize(user.role.value),
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          const Text('  ·  ', style: AppTypography.caption),
                          Flexible(
                            child: Text(
                              hasBranch ? branch : 'No branch',
                              style: AppTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge.active(user.isActive),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Performance metrics ───────────────────────────────
            _MetricStrip(metrics: metrics),
            // ── Actions ───────────────────────────────────────────
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.darkBorder, height: 1),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});
  final EmployeeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final rate = metrics.completionRatePct;
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          _metric('Completed', '${metrics.completed}', AppColors.success),
          _divider(),
          _metric('Pending', '${metrics.pending}', AppColors.textPrimary),
          _divider(),
          _metric('Rate', rate == null ? '—' : '$rate%', _rateColor(rate)),
          _divider(),
          _metric('Late', '${metrics.late}',
              metrics.late > 0 ? AppColors.warning : AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.label
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.caption, maxLines: 1),
          ],
        ),
      );

  Widget _divider() =>
      Container(width: 1, height: 26, color: AppColors.darkBorder);

  Color _rateColor(int? rate) {
    if (rate == null) return AppColors.textTertiary;
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return AppColors.warning;
    return AppColors.error;
  }
}
