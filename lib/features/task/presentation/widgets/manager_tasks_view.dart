import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_dialog.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/cubit/task_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_action_sheets.dart';
import 'package:fbro/features/task/presentation/widgets/task_card.dart';
import 'package:fbro/features/task/presentation/widgets/task_empty_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_template_sheets.dart';

/// Shared task screen for manager (own branch) and admin (global). Both create,
/// edit, assign, delete and review tasks; admins additionally set the branch on
/// create. The list itself is loaded by [TaskCubit] per the signed-in role.
class ManagerTasksView extends StatefulWidget {
  const ManagerTasksView({super.key, required this.title, required this.isAdmin});

  final String title;
  final bool isAdmin;

  @override
  State<ManagerTasksView> createState() => _ManagerTasksViewState();
}

class _ManagerTasksViewState extends State<ManagerTasksView> {
  UserEntity? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    _user = user;
    if (user != null) context.read<TaskCubit>().load(user);
  }

  String get _branchId => _user?.branchId ?? '';

  /// New Task is a two-step flow: choose blank vs. from-a-template, then open
  /// the prefilled task form. Templates cut the daily retyping of "Open Shop",
  /// "Night Checklist", etc.
  Future<void> _create() async {
    if (_user == null) return;
    final cubit = context.read<TaskCubit>();
    // Admin sees all templates (branch picked in the form); a manager sees
    // global + their own branch templates.
    final branchFilter = widget.isAdmin ? null : _branchId;
    final templates = await cubit.templates(branchId: branchFilter);
    if (!mounted) return;

    final choice =
        await showNewTaskChooserSheet(context, hasTemplates: templates.isNotEmpty);
    if (!mounted || choice == null) return;

    if (choice == NewTaskChoice.blank) {
      showTaskFormSheet(
        context: context,
        cubit: cubit,
        isAdmin: widget.isAdmin,
        defaultBranchId: _branchId,
      );
      return;
    }

    final template = await showTemplatePickerSheet(
      context: context,
      cubit: cubit,
      branchId: branchFilter,
    );
    if (!mounted || template == null) return;
    showTaskFormSheet(
      context: context,
      cubit: cubit,
      prefill: template,
      isAdmin: widget.isAdmin,
      defaultBranchId: _branchId,
    );
  }

  void _manageTemplates() {
    if (_user == null) return;
    showManageTemplatesSheet(
      context: context,
      cubit: context.read<TaskCubit>(),
      isAdmin: widget.isAdmin,
      defaultBranchId: _branchId,
    );
  }

  Future<void> _confirmDelete(TaskEntity task) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete task?',
      message: '"${task.title}" will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed && mounted) {
      context.read<TaskCubit>().deleteTask(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text(widget.title, style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined,
                color: AppColors.textSecondary),
            tooltip: 'Templates',
            onPressed: _manageTemplates,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => context.read<TaskCubit>().refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Task',
            style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (tasks, busy, directory) => _list(tasks, busy, directory),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(
      List<TaskEntity> tasks, bool busy, Map<String, UserEntity> directory) {
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<TaskCubit>().refresh(),
            child: tasks.isEmpty
                ? const TaskEmptyState(
                    icon: Icons.assignment_outlined,
                    message: 'No tasks yet.\nTap "New Task" to create one.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl * 2,
                    ),
                    children: [
                      for (var i = 0; i < tasks.length; i++)
                        EntranceFade(
                          delay: staggerDelay(i),
                          child: _card(tasks[i], directory),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _card(TaskEntity task, Map<String, UserEntity> directory) {
    final cubit = context.read<TaskCubit>();
    return TaskCard(
      task: task,
      directory: directory,
      onAssigneesTap: () =>
          showAssignSheet(context: context, cubit: cubit, task: task),
      actions: [
        if (task.status == TaskStatus.waitingReview)
          TaskActionButton(
            label: 'Review',
            icon: Icons.rate_review_outlined,
            color: AppColors.warning,
            onPressed: () =>
                showReviewSheet(context: context, cubit: cubit, task: task),
          ),
        TaskActionButton(
          label: 'Assign',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () =>
              showAssignSheet(context: context, cubit: cubit, task: task),
        ),
        TaskActionButton(
          label: 'Edit',
          icon: Icons.edit_outlined,
          onPressed: () => showTaskFormSheet(
            context: context,
            cubit: cubit,
            existing: task,
            isAdmin: widget.isAdmin,
            defaultBranchId: _branchId,
          ),
        ),
        TaskActionButton(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          color: AppColors.error,
          onPressed: () => _confirmDelete(task),
        ),
      ],
    );
  }
}
