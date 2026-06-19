import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_dialog.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/task/domain/entities/activity_entry.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/cubit/task_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_action_sheets.dart';
import 'package:fbro/features/task/presentation/widgets/task_card.dart';

/// Full-screen task details for all roles. Employees work through their
/// checklist and submit proof here. Managers see full context + review controls.
///
/// Keeps itself in sync with the [TaskCubit] stream by resolving the latest
/// snapshot of the same task id on every build (falls back to the initial [task]
/// if the cubit hasn't loaded yet or the task id isn't in the current list).
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.task,
    this.directory = const {},
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskCubit, TaskState>(
      listener: (context, state) =>
          state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
      builder: (context, state) {
        // Always show the freshest snapshot from the stream.
        final live = state.maybeWhen(
          loaded: (tasks, _, directory) {
            final found = tasks.where((t) => t.id == widget.task.id).toList();
            return found.isNotEmpty
                ? (task: found.first, directory: directory)
                : (task: widget.task, directory: widget.directory);
          },
          orElse: () => (task: widget.task, directory: widget.directory),
        );

        return _DetailsView(
          task: live.task,
          directory: live.directory,
          cubit: context.read<TaskCubit>(),
        );
      },
    );
  }
}

// ─── Main details view ──────────────────────────────────────────────

class _DetailsView extends StatelessWidget {
  const _DetailsView({
    required this.task,
    required this.directory,
    required this.cubit,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final TaskCubit cubit;

  @override
  Widget build(BuildContext context) {
    final role = context.currentRole;
    final isEmployee = role?.isEmployee ?? true;
    final isManagerOrAdmin = !(role?.isEmployee ?? true);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          task.title,
          style: AppTypography.label.copyWith(fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isManagerOrAdmin) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined,
                  color: AppColors.textSecondary),
              tooltip: 'Assign',
              onPressed: () =>
                  showAssignSheet(context: context, cubit: cubit, task: task),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary),
              tooltip: 'Edit',
              onPressed: () {
                final user = context.currentUser;
                showTaskFormSheet(
                  context: context,
                  cubit: cubit,
                  existing: task,
                  isAdmin: role?.isAdmin ?? false,
                  defaultBranchId: user?.branchId ?? '',
                );
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.sm,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          // ── Status + meta header ────────────────────────────────
          _StatusHeader(
            task: task,
            branchName: cubit.branchNames[task.branchId ?? ''],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Assignment ─────────────────────────────────────────
          _Section(
            icon: Icons.people_alt_outlined,
            title: 'Assigned to',
            child: _AssigneeBlock(task: task, directory: directory),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Description ─────────────────────────────────────────
          if ((task.description ?? '').isNotEmpty) ...[
            _Section(
              icon: Icons.notes_rounded,
              title: 'Description',
              child: Text(
                task.description!,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary, height: 1.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Checklist ──────────────────────────────────────────
          if (task.hasChecklist) ...[
            _Section(
              icon: Icons.checklist_rounded,
              title: 'Checklist',
              trailing: _ChecklistBadge(task: task),
              child: _ChecklistBlock(
                task: task,
                interactive: isEmployee && task.status == TaskStatus.started,
                onToggle: (item) => cubit.toggleChecklistItem(task, item.id),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Notes & proof ─────────────────────────────────────
          if ((task.notes ?? '').isNotEmpty || (task.proofImageUrl ?? '').isNotEmpty) ...[
            _Section(
              icon: Icons.rate_review_outlined,
              title: 'Submitted work',
              child: _SubmittedBlock(task: task),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Review notes ───────────────────────────────────────
          if ((task.reviewNotes ?? '').isNotEmpty) ...[
            _Section(
              icon: Icons.feedback_outlined,
              title: 'Review note',
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: task.status == TaskStatus.rejected
                      ? AppColors.errorSurface
                      : AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: task.status == TaskStatus.rejected
                        ? AppColors.error.withAlpha(60)
                        : AppColors.darkBorder,
                  ),
                ),
                child: Text(
                  task.reviewNotes!,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Activity timeline ──────────────────────────────────
          if (task.activityLog.isNotEmpty) ...[
            _Section(
              icon: Icons.timeline_rounded,
              title: 'Activity',
              child: _ActivityTimeline(log: task.activityLog, directory: directory),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Recurrence info ───────────────────────────────────
          if (task.recurrence != null &&
              task.recurrence!.frequency.value != 'none') ...[
            _Section(
              icon: Icons.repeat_rounded,
              title: 'Recurrence',
              child: Text(
                task.recurrence!.frequency.label,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Employee action area ───────────────────────────────
          if (isEmployee) ...[
            _EmployeeActions(task: task, cubit: cubit),
          ],

          // ── Manager / admin action area ────────────────────────
          if (isManagerOrAdmin &&
              task.status == TaskStatus.waitingReview) ...[
            _ReviewBlock(task: task, cubit: cubit),
          ],
        ],
      ),
    );
  }
}

// ─── Status header ─────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.task, this.branchName});
  final TaskEntity task;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status pill
          _StatusPill(task.status),
          const SizedBox(height: AppSpacing.md),
          // Meta row
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              if ((branchName ?? '').isNotEmpty)
                _MetaPill(
                  icon: Icons.store_mall_directory_outlined,
                  label: branchName!,
                ),
              _MetaPill(
                icon: Icons.flag_outlined,
                label: _priorityLabel(task.priority),
              ),
              _MetaPill(
                icon: Icons.label_outline_rounded,
                label: task.type.value,
              ),
              if (task.deadline != null) ...[
                _MetaPill(
                  icon: Icons.schedule_outlined,
                  label: _dateLabel(task.deadline!),
                  highlight: _isOverdue(task),
                ),
              ],
              if (task.recurrence != null &&
                  task.recurrence!.frequency.value != 'none')
                _MetaPill(
                  icon: Icons.repeat_rounded,
                  label: task.recurrence!.frequency.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg, label, icon) = _info(status);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  (Color, Color, String, IconData) _info(TaskStatus s) => switch (s) {
        TaskStatus.pending => (
            AppColors.textTertiary,
            AppColors.darkSurfaceElevated,
            'PENDING',
            Icons.circle_outlined,
          ),
        TaskStatus.started => (
            AppColors.textPrimary,
            AppColors.primarySurface,
            'IN PROGRESS',
            Icons.timelapse_rounded,
          ),
        TaskStatus.completed => (
            AppColors.textSecondary,
            AppColors.darkSurfaceElevated,
            'COMPLETED',
            Icons.check_circle_outline_rounded,
          ),
        TaskStatus.waitingReview => (
            AppColors.warning,
            AppColors.darkSurfaceElevated,
            'IN REVIEW',
            Icons.hourglass_empty_rounded,
          ),
        TaskStatus.approved => (
            AppColors.success,
            AppColors.successSurface,
            'APPROVED',
            Icons.check_circle_rounded,
          ),
        TaskStatus.rejected => (
            AppColors.error,
            AppColors.errorSurface,
            'NEEDS REWORK',
            Icons.replay_rounded,
          ),
      };
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(
      {required this.icon, required this.label, this.highlight = false});
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.error : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: AppTypography.caption
                .copyWith(color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Section wrapper ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text(title.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                )),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

// ─── Assignee block ─────────────────────────────────────────────────

class _AssigneeBlock extends StatelessWidget {
  const _AssigneeBlock({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    final assignees = resolveAssignees(task, directory);
    if (task.assigneeIds.isEmpty) {
      return Text('Unassigned',
          style: AppTypography.body.copyWith(color: AppColors.textTertiary));
    }
    return Column(
      children: [
        for (final u in assignees)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                UserAvatar.fromUser(u, size: 38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(u),
                        style: AppTypography.label,
                      ),
                      Text(
                        _roleLabel(u.role),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Assigned by
        if ((task.createdBy ?? '').isNotEmpty) ...[
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.person_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text('Assigned by  ',
                  style: AppTypography.caption),
              Text(
                _assignedByName(directory, task.createdBy!),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _name(UserEntity u) =>
      (u.displayName != null && u.displayName!.isNotEmpty)
          ? u.displayName!
          : u.email;

  String _roleLabel(UserRole r) => switch (r) {
        UserRole.admin => 'Admin',
        UserRole.manager => 'Manager',
        UserRole.employee => 'Employee',
      };

  String _assignedByName(Map<String, UserEntity> dir, String uid) {
    final u = dir[uid];
    if (u != null) {
      final n = _name(u);
      return '$n · ${_roleLabel(u.role)}';
    }
    return 'Admin';
  }
}

// ─── Checklist block ─────────────────────────────────────────────────

class _ChecklistBadge extends StatelessWidget {
  const _ChecklistBadge({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;
    return Text(
      '$done / $total',
      style: AppTypography.caption.copyWith(
        color: complete ? AppColors.success : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChecklistBlock extends StatelessWidget {
  const _ChecklistBlock({
    required this.task,
    required this.interactive,
    required this.onToggle,
  });

  final TaskEntity task;
  final bool interactive;
  final void Function(ChecklistItem item) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: task.checklistProgress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: AppColors.darkSurfaceElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Checklist items
        for (final item in task.checklist)
          _ChecklistRow(
            item: item,
            interactive: interactive,
            onTap: () => onToggle(item),
          ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.interactive,
    required this.onTap,
  });

  final ChecklistItem item;
  final bool interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: interactive ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: item.completed
              ? AppColors.primarySurface
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.completed ? AppColors.white : AppColors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color:
                      item.completed ? AppColors.white : AppColors.textTertiary,
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('optional',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Submitted block ────────────────────────────────────────────────

class _SubmittedBlock extends StatelessWidget {
  const _SubmittedBlock({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final notes = task.notes ?? '';
    final proof = task.proofImageUrl ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            Text(notes,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary, height: 1.5)),
          ],
          if (proof.isNotEmpty) ...[
            if (notes.isNotEmpty) const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                proof,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 1200,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 200,
                        color: AppColors.darkSurface,
                        alignment: Alignment.center,
                        child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                errorBuilder: (ctx, err, st) => Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  child: Text('Proof image unavailable',
                      style: AppTypography.caption),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Activity timeline ──────────────────────────────────────────────

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.log, required this.directory});
  final List<ActivityEntry> log;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    // Show newest first.
    final entries = log.reversed.toList();
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            directory: directory,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.directory,
    required this.isLast,
  });

  final ActivityEntry entry;
  final Map<String, UserEntity> directory;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final actor = directory[entry.actorId];
    final name = entry.actorName ??
        (actor != null
            ? (actor.displayName ?? actor.email)
            : 'Unknown');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor(entry.status),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: AppColors.darkBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _statusLabel(entry.status),
                        style: AppTypography.label
                            .copyWith(color: _dotColor(entry.status)),
                      ),
                      const Spacer(),
                      Text(
                        _timeLabel(entry.at),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(name, style: AppTypography.bodySmall),
                  if ((entry.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.note!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(String status) => switch (status) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        'started' || 'waitingReview' => AppColors.textPrimary,
        _ => AppColors.textTertiary,
      };

  String _statusLabel(String s) => switch (s) {
        'pending' => 'Created',
        'started' => 'Started',
        'completed' => 'Completed',
        'waitingReview' => 'Submitted for review',
        'approved' => 'Approved',
        'rejected' => 'Rework requested',
        _ => s,
      };

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day} ${_months[dt.month - 1]}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ─── Employee action area ───────────────────────────────────────────

class _EmployeeActions extends StatelessWidget {
  const _EmployeeActions({required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;

  @override
  Widget build(BuildContext context) {
    return switch (task.status) {
      TaskStatus.pending => AppButton(
          label: 'Start Task',
          icon: const Icon(Icons.play_arrow_rounded,
              size: 20, color: AppColors.textDark),
          onPressed: () => cubit.startTask(task),
        ),
      TaskStatus.started => _CompleteButton(task: task, cubit: cubit),
      TaskStatus.completed => AppButton(
          label: 'Submit for Review',
          icon: const Icon(Icons.send_rounded,
              size: 18, color: AppColors.textDark),
          onPressed: () {
            cubit.submitForReview(task);
            Navigator.of(context).pop();
          },
        ),
      TaskStatus.rejected => AppButton(
          label: 'Start Rework',
          icon: const Icon(Icons.replay_rounded,
              size: 18, color: AppColors.textDark),
          onPressed: () => cubit.startTask(task),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _CompleteButton extends StatefulWidget {
  const _CompleteButton({required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;

  @override
  State<_CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<_CompleteButton> {
  File? _proof;
  final _notes = TextEditingController();
  bool _expanded = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (picked != null) setState(() => _proof = File(picked.path));
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not pick an image.');
    }
  }

  Future<void> _submit() async {
    final notes = _notes.text.trim();
    final ok = await widget.cubit.completeAndSubmit(
      widget.task,
      notes: notes.isEmpty ? null : notes,
      proof: _proof,
    );
    // Only leave the screen on success. On failure the cubit already surfaced
    // the real error and the selected photo is still attached here, so the
    // employee can retry (or remove the photo) without losing their work.
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_expanded)
          AppButton(
            label: 'Mark Complete',
            icon: const Icon(Icons.check_rounded,
                size: 20, color: AppColors.textDark),
            onPressed: () {
              if (!widget.task.requiredChecklistComplete) {
                AppSnackbar.error(
                  context,
                  'Complete all required checklist items first.',
                );
                return;
              }
              setState(() => _expanded = true);
            },
          )
        else ...[
          AppTextField(
            controller: _notes,
            label: 'Notes (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _pickProof,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  if (_proof != null)
                    ClipRRect(
                      borderRadius: AppRadius.cardAll,
                      child: Image.file(_proof!,
                          width: 44, height: 44, fit: BoxFit.cover),
                    )
                  else
                    const Icon(Icons.add_a_photo_outlined,
                        size: 22, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _proof == null
                          ? 'Attach proof image (optional)'
                          : 'Photo selected — tap to change',
                      style: AppTypography.body,
                    ),
                  ),
                  if (_proof != null)
                    GestureDetector(
                      onTap: () => setState(() => _proof = null),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.sm),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Complete & Submit',
            icon: const Icon(Icons.send_rounded,
                size: 20, color: AppColors.textDark),
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.ghost(
            label: 'Cancel',
            onPressed: () => setState(() => _expanded = false),
          ),
        ],
      ],
    );
  }
}

// ─── Manager / admin review block ──────────────────────────────────

class _ReviewBlock extends StatefulWidget {
  const _ReviewBlock({required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;

  @override
  State<_ReviewBlock> createState() => _ReviewBlockState();
}

class _ReviewBlockState extends State<_ReviewBlock> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? get _note =>
      _notes.text.trim().isEmpty ? null : _notes.text.trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppColors.darkBorder),
        const SizedBox(height: AppSpacing.md),
        Text('Review submission', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _notes,
          label: 'What needs fixing? (optional)',
          prefixIcon: Icons.rate_review_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Approve',
          icon: const Icon(Icons.check_circle_outline_rounded,
              size: 20, color: AppColors.textDark),
          onPressed: () {
            widget.cubit.approveTask(widget.task, reviewNotes: _note);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        // "Request rework" sends the task back for the employee to fix (the
        // existing rejected → restart path) — a normal workflow step, not a
        // destructive action, so no red confirm.
        AppButton.secondary(
          label: 'Request Rework',
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Request rework?',
              message: 'The employee will be asked to fix and resubmit it.',
              confirmLabel: 'Request rework',
            );
            if (confirmed && context.mounted) {
              widget.cubit.rejectTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

bool _isOverdue(TaskEntity task) {
  final d = task.deadline;
  if (d == null) return false;
  final done = task.status == TaskStatus.approved ||
      task.status == TaskStatus.completed ||
      task.status == TaskStatus.waitingReview;
  return !done && d.isBefore(DateTime.now());
}

String _dateLabel(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String _priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.high => 'High priority',
      TaskPriority.normal => 'Medium priority',
      TaskPriority.low => 'Low priority',
    };
