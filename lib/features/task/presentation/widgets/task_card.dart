import 'package:flutter/material.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/status_badge.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';

/// Premium, glass-like card for a single task (Phase 9 redesign).
///
/// Hierarchy: a priority rail + title + status badge on top, then the resolved
/// assignees (avatars · name · role), the checklist progress, meta chips, any
/// employee/review notes + proof, and finally the role/status-aware [actions].
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.directory = const {},
    this.actions = const [],
    this.onAssigneesTap,
    this.onChecklistToggle,
  });

  final TaskEntity task;

  /// uid → user, used to render real assignee names/avatars.
  final Map<String, UserEntity> directory;
  final List<Widget> actions;

  /// Opens the assignee sheet when the assignees row is tapped.
  final VoidCallback? onAssigneesTap;

  /// When provided, the checklist is rendered as interactive (tappable) rows —
  /// used by the assigned employee while the task is in progress.
  final void Function(ChecklistItem item)? onChecklistToggle;

  @override
  Widget build(BuildContext context) {
    final description = task.description ?? '';
    final notes = task.notes ?? '';
    final reviewNotes = task.reviewNotes ?? '';
    final proof = task.proofImageUrl ?? '';
    final priorityColor = _priorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(46),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg + AppSpacing.xs,
                AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(task.title,
                          style: AppTypography.labelLarge
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge.task(task.status),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(description,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.md),
                _AssigneesRow(
                  task: task,
                  directory: directory,
                  onTap: onAssigneesTap,
                ),
                if (task.hasChecklist) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ChecklistSection(
                    task: task,
                    onToggle: onChecklistToggle,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _PriorityChip(priority: task.priority),
                    _MetaChip(
                        icon: Icons.category_outlined, label: task.type.value),
                    if (task.deadline != null)
                      _MetaChip(
                          icon: Icons.event_outlined,
                          label: _date(task.deadline!)),
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
                    borderRadius: BorderRadius.circular(12),
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
          ),
          // Full-height priority rail — a positioned element (not a stretched
          // flex child) so it can't force an infinite height inside an
          // unbounded-height list. Fixes the Tasks-screen layout crash
          // ("BoxConstraints forces an infinite height").
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: const BorderRadiusDirectional.horizontal(
                    start: Radius.circular(AppRadius.card)),
              ),
            ),
          ),
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

/// Resolves a task's assignee uids to users from [directory] (the ones not yet
/// resolved are dropped here but counted in [TaskEntity.assigneeIds]).
List<UserEntity> resolveAssignees(
        TaskEntity task, Map<String, UserEntity> directory) =>
    [
      for (final uid in task.assigneeIds)
        if (directory[uid] != null) directory[uid]!,
    ];

String _bestName(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty)
        ? u.displayName!
        : u.email;

class _AssigneesRow extends StatelessWidget {
  const _AssigneesRow({
    required this.task,
    required this.directory,
    this.onTap,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveAssignees(task, directory);
    final total = task.assigneeIds.length;

    final Widget content;
    if (total == 0) {
      content = Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkSurface,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(Icons.person_add_alt_1_outlined,
                size: 18, color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Unassigned', style: AppTypography.bodySmall),
        ],
      );
    } else if (resolved.length == 1 && total == 1) {
      final u = resolved.first;
      content = Row(
        children: [
          UserAvatar.fromUser(u, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bestName(u),
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(u.role.value, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          if (resolved.isNotEmpty)
            AvatarStack(users: resolved, size: 32)
          else
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkSurfaceElevated,
              ),
              child: const Icon(Icons.groups_outlined,
                  size: 16, color: AppColors.textTertiary),
            ),
          const SizedBox(width: AppSpacing.md),
          Text('$total assigned', style: AppTypography.label),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: content),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Checklist progress bar + (optionally interactive) item rows.
class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.task, this.onToggle});

  final TaskEntity task;
  final void Function(ChecklistItem item)? onToggle;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded,
                size: 15,
                color: complete ? AppColors.success : AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              complete ? '100% complete' : '$done / $total completed',
              style: AppTypography.caption.copyWith(
                color: complete ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: task.checklistProgress),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppColors.darkSurface,
              valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.success : AppColors.primary),
            ),
          ),
        ),
        if (onToggle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final item in task.checklist)
            _ChecklistRow(item: item, onTap: () => onToggle!(item)),
        ],
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, required this.onTap});
  final ChecklistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: item.completed
                    ? AppColors.success
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.completed
                      ? AppColors.success
                      : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
              child: item.completed
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: AppColors.black)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.title,
                style: AppTypography.body.copyWith(
                  color: item.completed
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  decoration:
                      item.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!item.isRequired)
              Text('optional', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('${priority.value} priority', style: AppTypography.caption),
        ],
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

Color _priorityColor(TaskPriority p) {
  switch (p) {
    case TaskPriority.high:
      return AppColors.error;
    case TaskPriority.normal:
      return AppColors.warning;
    case TaskPriority.low:
      return AppColors.textTertiary;
  }
}

