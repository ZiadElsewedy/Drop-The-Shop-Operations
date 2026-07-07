import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/work_types/task_work_x.dart';
import 'package:drop/features/task/presentation/attachment_format.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/submission_progress.dart';
import 'package:drop/features/task/presentation/widgets/activity_timeline.dart';
import 'package:drop/features/task/presentation/widgets/attachment_gallery.dart';
import 'package:drop/features/task/presentation/widgets/attachment_picker.dart';
import 'package:drop/features/task/presentation/widgets/submission_loading_overlay.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart';
import 'package:drop/features/task/presentation/widgets/task_card.dart';
import 'package:drop/features/task/presentation/widgets/task_surface.dart';
import 'package:drop/features/task/presentation/widgets/work_type_panel.dart';
import 'package:drop/features/task/presentation/work_type_presenter.dart';

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
        // Always show the freshest snapshot from the stream, plus the shared
        // submission state (drives the single loading overlay).
        final live = state.maybeWhen(
          loaded: (tasks, busy, directory, isSubmitting, submissionProgress) {
            final found = tasks.where((t) => t.id == widget.task.id).toList();
            return (
              task: found.isNotEmpty ? found.first : widget.task,
              directory: directory,
              submitting: isSubmitting,
              progress: submissionProgress,
            );
          },
          orElse: () => (
            task: widget.task,
            directory: widget.directory,
            submitting: false,
            progress: null,
          ),
        );

        return PopScope(
          // Block back navigation while a submission is in flight.
          canPop: !live.submitting,
          child: Stack(
            children: [
              _DetailsView(
                task: live.task,
                directory: live.directory,
                cubit: context.read<TaskCubit>(),
              ),
              if (live.submitting)
                Positioned.fill(
                  child: SubmissionLoadingOverlay(
                    progress: live.progress ??
                        const SubmissionProgress(SubmissionStage.preparing),
                  ),
                ),
            ],
          ),
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

  Future<void> _confirmReopen(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reopen task?',
      message:
          'This moves the task back into the workflow so it can be edited. The approval will be cleared.',
      confirmLabel: 'Reopen',
    );
    if (confirmed && context.mounted) cubit.reopenTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.currentRole;
    final isEmployee = role?.isEmployee ?? true;
    final isManagerOrAdmin = !(role?.isEmployee ?? true);
    final isAdmin = role?.isAdmin ?? false;
    // An approved task is a locked, reviewed record — no Assign / Edit.
    final isLocked = task.status == TaskStatus.approved;
    // Branch identity from the app-wide directory (§8b) — drives the cover
    // banner + logo. Watched so it fills in once the directory preloads.
    final branch = context.watch<BranchCubit>().branchById(task.branchId);

    return AdaptiveScaffold(
      title: task.title,
      constrainContent: false,
      actions: [
        if (isManagerOrAdmin && !isLocked) ...[
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
                isAdmin: isAdmin,
                defaultBranchId: user?.branchId ?? '',
              );
            },
          ),
        ],
        // Approved & locked: an admin keeps a Reopen escape hatch; a manager
        // sees only a non-interactive lock glyph.
        if (isManagerOrAdmin && isLocked)
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.lock_open_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Reopen',
              onPressed: () => _confirmReopen(context),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(Icons.lock_outline_rounded,
                  size: 20, color: AppColors.textTertiary),
            ),
      ],
      body: context.isDesktop
          ? _desktopBody(
              context, isEmployee, isManagerOrAdmin, isAdmin, isLocked)
          : ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.sm,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          // ── Branch cover banner (identity) ──────────────────────
          // When the task's branch has an uploaded cover photo, lead with it so
          // the task visibly belongs to its branch (reuses the §8 branch media +
          // the §8b app-wide BranchCubit directory). Hidden when there's no cover.
          if (branch?.coverUrl != null && branch!.coverUrl!.isNotEmpty) ...[
            _BranchBanner(branch: branch),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Status + meta header ────────────────────────────────
          _StatusHeader(
            task: task,
            branchName: cubit.branchNames[task.branchId ?? ''],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Locked notice (approved) ───────────────────────────
          if (isLocked) ...[
            _LockedBanner(canReopen: isAdmin),
            const SizedBox(height: AppSpacing.xl),
          ],

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

          // ── Work type (adaptive) ───────────────────────────────
          if (WorkTypePanel.hasContentFor(task)) ...[
            _Section(
              icon: WorkTypePresenter.iconFor(task.workType),
              title: task.workDefinition.label,
              child: WorkTypePanel(
                task: task,
                cubit: cubit,
                interactive: isEmployee && task.status == TaskStatus.started,
                showReviewHint: isManagerOrAdmin,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Reference images (manager-attached) ────────────────
          if (task.hasReferences) ...[
            _Section(
              icon: Icons.image_outlined,
              title: 'Reference',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What good looks like — attached by the manager.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AttachmentGallery(
                    attachments: task.referenceAttachments,
                    columns: 2,
                    showDuration: true,
                    showCaption: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Checklist ──────────────────────────────────────────
          if (task.hasChecklist && !task.workDefinition.usesChecklistAsPoints) ...[
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

          // ── Notes & media ─────────────────────────────────────
          if ((task.notes ?? '').isNotEmpty ||
              latestAttachments(task).isNotEmpty) ...[
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
              child: ActivityTimeline(
                task: task,
                directory: directory,
                cubit: cubit,
                canReview: isManagerOrAdmin,
              ),
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

  // ── Desktop: two-column ticket inspection (Linear/Jira style) ──────
  // Left = the ticket record (status, description, proof, activity); right =
  // a dedicated, sticky action panel (assignment + approve/rework/submit).
  Widget _desktopBody(
    BuildContext context,
    bool isEmployee,
    bool isManagerOrAdmin,
    bool isAdmin,
    bool isLocked,
  ) {
    final branch = context.watch<BranchCubit>().branchById(task.branchId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main record ────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(40, 24, 28, 48),
            children: [
              if (branch?.coverUrl != null && branch!.coverUrl!.isNotEmpty) ...[
                _BranchBanner(branch: branch),
                const SizedBox(height: AppSpacing.lg),
              ],
              _StatusHeader(
                task: task,
                branchName: cubit.branchNames[task.branchId ?? ''],
              ),
              const SizedBox(height: AppSpacing.xl),
              if ((task.description ?? '').isNotEmpty) ...[
                _Section(
                  icon: Icons.notes_rounded,
                  title: 'Description',
                  child: Text(
                    task.description!,
                    style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary, height: 1.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (WorkTypePanel.hasContentFor(task)) ...[
                _Section(
                  icon: WorkTypePresenter.iconFor(task.workType),
                  title: task.workDefinition.label,
                  child: WorkTypePanel(
                    task: task,
                    cubit: cubit,
                    interactive:
                        isEmployee && task.status == TaskStatus.started,
                    showReviewHint: isManagerOrAdmin,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (task.hasReferences) ...[
                _Section(
                  icon: Icons.image_outlined,
                  title: 'Reference',
                  child: AttachmentGallery(
                    attachments: task.referenceAttachments,
                    columns: 3,
                    showDuration: true,
                    showCaption: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (task.hasChecklist && !task.workDefinition.usesChecklistAsPoints) ...[
                _Section(
                  icon: Icons.checklist_rounded,
                  title: 'Checklist',
                  trailing: _ChecklistBadge(task: task),
                  child: _ChecklistBlock(
                    task: task,
                    interactive:
                        isEmployee && task.status == TaskStatus.started,
                    onToggle: (item) =>
                        cubit.toggleChecklistItem(task, item.id),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if ((task.notes ?? '').isNotEmpty ||
                  latestAttachments(task).isNotEmpty) ...[
                _Section(
                  icon: Icons.rate_review_outlined,
                  title: 'Submitted work',
                  child: _SubmittedBlock(task: task),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
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
                      style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (task.activityLog.isNotEmpty)
                _Section(
                  icon: Icons.timeline_rounded,
                  title: 'Activity',
                  child: ActivityTimeline(
                    task: task,
                    directory: directory,
                    cubit: cubit,
                    canReview: isManagerOrAdmin,
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.darkBorder),
        // ── Action / context panel ─────────────────────────────────
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 40, 48),
            children: [
              if (isLocked) ...[
                _LockedBanner(canReopen: isAdmin),
                const SizedBox(height: AppSpacing.xl),
              ],
              _Section(
                icon: Icons.people_alt_outlined,
                title: 'Assigned to',
                child: _AssigneeBlock(task: task, directory: directory),
              ),
              if (task.recurrence != null &&
                  task.recurrence!.frequency.value != 'none') ...[
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  icon: Icons.repeat_rounded,
                  title: 'Recurrence',
                  child: Text(
                    task.recurrence!.frequency.label,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
              if (!isLocked &&
                  (isEmployee ||
                      (isManagerOrAdmin &&
                          task.status == TaskStatus.waitingReview))) ...[
                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.darkBorder),
                const SizedBox(height: AppSpacing.lg),
                if (isEmployee)
                  _EmployeeActions(task: task, cubit: cubit)
                else
                  _ReviewBlock(task: task, cubit: cubit),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Status header ─────────────────────────────────────────────────

/// The task's status header — **de-flashed** (2026-06-25): a flat solid surface
/// with a hairline border and a whisper of depth. No breathing pulse, no glow,
/// no gradient (the status pill carries the state; it still cross-fades on a
/// status change, which is a one-shot transition, not a pulse).
/// A slim branch **cover** banner for the task details header — the branch's
/// uploaded cover photo (dark scrim for legibility) with its logo + name
/// overlaid. Reuses the §8 branch media + the Operations branch-hero pattern,
/// scaled down to a header strip so the task reads as belonging to its branch.
class _BranchBanner extends StatelessWidget {
  const _BranchBanner({required this.branch});
  final BranchEntity branch;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              branch.coverUrl!,
              fit: BoxFit.cover,
              cacheWidth: 1200,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.darkSurface),
            ),
            // Dark scrim (stronger at the bottom, where the label sits).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x40000000), Color(0xCC000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BranchAvatar(
                      logoUrl: branch.logoUrl,
                      name: branch.name,
                      size: 34,
                      radius: 9),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: AppTypography.label.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((branch.location ?? '').isNotEmpty)
                          Text(
                            branch.location!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.task, this.branchName});
  final TaskEntity task;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    // Reuses the shared de-flashed [TaskSurface] (same flat surface + whisper
    // shadow as the task card) so the treatment is defined in one place.
    return TaskSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadius.cardAll,
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
    // Cross-fade + scale the badge whenever the status changes (the screen
    // rebuilds from the live stream), giving a subtle icon scale/fade.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: _pill(),
    );
  }

  Widget _pill() {
    final (color, bg, label, icon) = _info(status);
    return Container(
      key: ValueKey(status),
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
    if (task.assignmentType == TaskAssignmentType.shift) {
      // Shift Assignment feature: targets whoever's rostered on task.shift,
      // not a named assignee — assigneeIds is always empty here.
      return Row(
        children: [
          const Icon(Icons.schedule_rounded,
              size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            task.shift == null ? 'Shift task' : '${task.shift!.label} Shift',
            style: AppTypography.body,
          ),
        ],
      );
    }
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
    final media = latestAttachments(task);

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
          if (notes.isNotEmpty)
            Text(notes,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary, height: 1.5)),
          if (media.isNotEmpty) ...[
            if (notes.isNotEmpty) const SizedBox(height: AppSpacing.md),
            AttachmentGallery(attachments: media, tileSize: 84),
          ],
        ],
      ),
    );
  }
}

// ─── Employee action area ───────────────────────────────────────────

/// Shown at the top of an approved task's details — a calm, monochrome notice
/// that the task is a locked, reviewed record (the status glow on the header
/// above carries the colour; this banner stays neutral).
class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.canReopen});
  final bool canReopen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              canReopen
                  ? 'Approved and locked. Reopen the task to make changes.'
                  : 'Approved and locked. This task can no longer be changed.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

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
  List<PickedAttachment> _attachments = [];
  final _notes = TextEditingController();
  bool _expanded = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notes = _notes.text.trim();
    // The submission overlay is driven by TaskCubit/TaskState (rendered by the
    // screen), so the button just kicks off the work and leaves on success.
    final ok = await widget.cubit.completeAndSubmit(
      widget.task,
      notes: notes.isEmpty ? null : notes,
      attachments: _attachments,
    );
    // On failure the cubit already surfaced the real error and the selected
    // media is still attached here, so the employee can retry without losing it.
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
          AttachmentPickerField(
            attachments: _attachments,
            onChanged: (list) => setState(() => _attachments = list),
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
        // "Request rework" sends the task back for the employee to fix (bumps
        // the revision → REWORK #n) — a normal workflow step, not destructive.
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
              widget.cubit.reworkTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            }
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        // Terminal "Reject" — distinct from rework (no resubmit expected); red,
        // destructive confirm.
        TextButton(
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Reject task?',
              message:
                  'This rejects the submission. Use Request Rework instead if '
                  'the employee should fix and resubmit it.',
              confirmLabel: 'Reject',
              destructive: true,
            );
            if (confirmed && context.mounted) {
              widget.cubit.rejectTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            }
          },
          child: Text('Reject',
              style: AppTypography.label.copyWith(color: AppColors.error)),
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
