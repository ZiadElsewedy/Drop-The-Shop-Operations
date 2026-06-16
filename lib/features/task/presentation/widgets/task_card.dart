import 'package:flutter/material.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';

/// Presentational card for a single task. The screen supplies role/status-aware
/// [actions] (built with [TaskActionButton]).
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.actions = const []});

  final TaskEntity task;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final description = task.description ?? '';
    final notes = task.notes ?? '';
    final reviewNotes = task.reviewNotes ?? '';
    final proof = task.proofImageUrl ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(task.title, style: AppTypography.label)),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(status: task.status),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(icon: Icons.category_outlined, label: task.type.value),
              _MetaChip(icon: Icons.flag_outlined, label: task.priority.value),
              _MetaChip(
                icon: Icons.person_outline_rounded,
                label: (task.assignedEmployeeId == null ||
                        task.assignedEmployeeId!.isEmpty)
                    ? 'unassigned'
                    : 'assigned',
              ),
              if (task.deadline != null)
                _MetaChip(
                    icon: Icons.event_outlined, label: _date(task.deadline!)),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _NoteLine(label: 'Notes', text: notes),
          ],
          if (reviewNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _NoteLine(label: 'Review', text: reviewNotes),
          ],
          if (proof.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                proof,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, _, _) => Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  child: Text('Proof image attached',
                      style: AppTypography.caption),
                ),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Compact pill button for task card actions.
class TaskActionButton extends StatelessWidget {
  const TaskActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.chevron_right_rounded, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.primary,
        backgroundColor: AppColors.darkSurfaceElevated,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        textStyle: AppTypography.caption,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        _statusLabel(status),
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTypography.bodySmall,
        children: [
          TextSpan(
            text: '$label: ',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

Color _statusColor(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return AppColors.textTertiary;
    case TaskStatus.started:
    case TaskStatus.waitingReview:
      return AppColors.warning;
    case TaskStatus.completed:
      return AppColors.primary;
    case TaskStatus.approved:
      return AppColors.success;
    case TaskStatus.rejected:
      return AppColors.error;
  }
}

String _statusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return 'Pending';
    case TaskStatus.started:
      return 'Started';
    case TaskStatus.completed:
      return 'Completed';
    case TaskStatus.waitingReview:
      return 'Waiting Review';
    case TaskStatus.approved:
      return 'Approved';
    case TaskStatus.rejected:
      return 'Rejected';
  }
}
