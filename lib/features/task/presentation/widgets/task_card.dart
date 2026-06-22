import 'package:flutter/material.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/widgets/task_badge.dart';

/// A clean, enterprise task card — monochrome (black / white / grey), built for
/// scanning, not decoration. Hierarchy:
///
///   Title ················· status (subtle dot + label)
///   Description
///   ─ assignee (avatar · name · role)
///   Assigned by ·· Manager who created it     ← who sent the task
///   Due ·········· date (· Overdue when late)
///   Priority ····· low / medium / high (no colour)
///   checklist progress (greyscale)
///   actions
///
/// No priority rail, no coloured chips, no loud status badges — just a calm
/// surface with clear typographic hierarchy.
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

  /// uid → user, used to render real assignee + creator names/avatars.
  final Map<String, UserEntity> directory;
  final List<Widget> actions;

  /// Opens the assignee sheet when the assignee row is tapped.
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
    final assignedBy = _assignedBy(directory, task);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Lifecycle badge (NEW / REWORK #n / Rejected / Approved) ──
          if (taskBadgeFor(task) != null) ...[
            TaskBadge(task: task),
            const SizedBox(height: AppSpacing.sm),
          ],
          // ── Title + status ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _StatusChip(task.status),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          _AssigneeLine(task: task, directory: directory, onTap: onAssigneesTap),

          // ── Meta (who / when / priority) ────────────────────────
          const SizedBox(height: AppSpacing.md),
          if (assignedBy != null) _MetaRow(label: 'Assigned by', value: assignedBy),
          if (task.deadline != null)
            _MetaRow(
              label: 'Due',
              value: _dateLabel(task.deadline!),
              trailing: _isOverdue(task) ? 'Overdue' : null,
            ),
          _MetaRow(label: 'Priority', value: _priorityLabel(task.priority)),

          if (task.hasChecklist) ...[
            const SizedBox(height: AppSpacing.md),
            _ChecklistSection(task: task, onToggle: onChecklistToggle),
          ],

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
                errorBuilder: (ctx, err, st) => Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  child: Text('Proof image attached',
                      style: AppTypography.caption),
                ),
              ),
            ),
          ],

          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.darkBorder),
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
}

// ─── Helpers ───────────────────────────────────────────────────────

/// "Name · Role" for the task's creator, resolved from the directory. Creators
/// not in the branch directory are global admins, so we label them "Admin".
String? _assignedBy(Map<String, UserEntity> directory, TaskEntity task) {
  final by = task.createdBy ?? '';
  if (by.isEmpty) return null;
  final u = directory[by];
  if (u != null) return '${_bestName(u)} · ${_roleLabel(u.role)}';
  return 'Admin';
}

String _roleLabel(UserRole r) => switch (r) {
      UserRole.admin => 'Admin',
      UserRole.manager => 'Manager',
      UserRole.employee => 'Employee',
    };

String _priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.high => 'High',
      TaskPriority.normal => 'Medium',
      TaskPriority.low => 'Low',
    };

bool _isOverdue(TaskEntity task) {
  final d = task.deadline;
  if (d == null) return false;
  final terminal = task.status == TaskStatus.approved ||
      task.status == TaskStatus.completed ||
      task.status == TaskStatus.waitingReview;
  return !terminal && d.isBefore(DateTime.now());
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _bestName(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty)
        ? u.displayName!
        : u.email;

/// Subtle monochrome status indicator — a small glyph + label. Active states
/// (in progress / in review / rejected) read in white; resting states in grey.
class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, active) = _info(status);
    final color = active ? AppColors.textPrimary : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  (IconData, String, bool) _info(TaskStatus s) => switch (s) {
        TaskStatus.pending => (Icons.circle_outlined, 'Pending', false),
        TaskStatus.started => (Icons.timelapse_rounded, 'In progress', true),
        TaskStatus.completed => (Icons.check_circle_outline_rounded, 'Completed', false),
        TaskStatus.waitingReview => (Icons.hourglass_empty_rounded, 'In review', true),
        TaskStatus.approved => (Icons.check_circle_rounded, 'Approved', false),
        TaskStatus.rejected => (Icons.replay_rounded, 'Needs rework', true),
      };
}

/// A clean key→value meta row, e.g. "Assigned by   Ahmed Hassan · Manager".
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value, this.trailing});
  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact, monochrome text-button for task card actions.
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

  /// Reserved for destructive affordances (e.g. Delete); defaults to the
  /// monochrome foreground.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.chevron_right_rounded, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.textPrimary,
        backgroundColor: AppColors.darkSurfaceElevated,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        textStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Resolves a task's assignee uids to users from [directory].
List<UserEntity> resolveAssignees(
        TaskEntity task, Map<String, UserEntity> directory) =>
    [
      for (final uid in task.assigneeIds)
        if (directory[uid] != null) directory[uid]!,
    ];

/// The assignee line on the card: avatar · name · role (single), an avatar stack
/// + count (many), or an "Unassigned" affordance.
class _AssigneeLine extends StatelessWidget {
  const _AssigneeLine({required this.task, required this.directory, this.onTap});

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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkSurfaceElevated,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(Icons.person_add_alt_1_outlined,
                size: 16, color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Unassigned', style: AppTypography.bodySmall),
        ],
      );
    } else if (resolved.length == 1 && total == 1) {
      final u = resolved.first;
      content = Row(
        children: [
          UserAvatar.fromUser(u, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bestName(u),
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_roleLabel(u.role), style: AppTypography.caption),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          if (resolved.isNotEmpty)
            AvatarStack(users: resolved, size: 30)
          else
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkSurfaceElevated,
              ),
              child: const Icon(Icons.groups_outlined,
                  size: 15, color: AppColors.textTertiary),
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

/// Greyscale checklist progress bar + (optionally interactive) item rows.
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
            const Icon(Icons.checklist_rounded,
                size: 14, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              complete ? 'Checklist complete' : '$done of $total done',
              style: AppTypography.caption.copyWith(
                color:
                    complete ? AppColors.textPrimary : AppColors.textSecondary,
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
              backgroundColor: AppColors.darkSurfaceElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
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
                color:
                    item.completed ? AppColors.white : AppColors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.completed
                      ? AppColors.white
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
