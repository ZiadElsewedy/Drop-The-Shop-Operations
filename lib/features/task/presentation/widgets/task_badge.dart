import 'package:flutter/material.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// The label + colour of a task's lifecycle badge (Notification System Phase 1,
/// Part 5). Pure + unit-testable. Returns `null` when no badge applies (e.g. a
/// task that's started / in review / has no distinguishing state).
///
/// Precedence: rework → approved → rejected → new. Colours follow the locked
/// design decision — **NEW stays monochrome** (white accent); REWORK→amber,
/// Rejected→red, Approved→green use the existing semantic palette.
({String label, Color color})? taskBadgeFor(TaskEntity task) {
  if (task.requiresRework) {
    return (label: 'REWORK #${task.revisionNumber}', color: AppColors.warning);
  }
  if (task.status == TaskStatus.approved) {
    return (label: 'Approved', color: AppColors.success);
  }
  if (task.status == TaskStatus.rejected) {
    return (label: 'Rejected', color: AppColors.error);
  }
  if (task.isNew) {
    return (label: 'NEW', color: AppColors.primary);
  }
  return null;
}

/// A small tinted pill rendering [taskBadgeFor]. Renders nothing when no badge
/// applies, so it can be dropped into a row unconditionally.
class TaskBadge extends StatelessWidget {
  const TaskBadge({super.key, required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final badge = taskBadgeFor(task);
    if (badge == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badge.color.withAlpha(34),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badge.color.withAlpha(110)),
      ),
      child: Text(
        badge.label,
        style: AppTypography.caption.copyWith(
          color: badge.color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
