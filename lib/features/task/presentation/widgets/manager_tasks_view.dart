import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
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
    final user = context.read<AuthCubit>().state.maybeWhen(
          authenticated: (u) => u,
          orElse: () => null,
        );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        title: Text('Delete task?', style: AppTypography.h3),
        content: Text('"${task.title}" will be permanently removed.',
            style: AppTypography.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
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
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Task',
            style: AppTypography.label.copyWith(color: AppColors.textDark)),
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          loaded: (tasks, busy) => _list(tasks, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(List<TaskEntity> tasks, bool busy) {
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
                    children: [for (final t in tasks) _card(t)],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _card(TaskEntity task) {
    final cubit = context.read<TaskCubit>();
    return TaskCard(
      task: task,
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
