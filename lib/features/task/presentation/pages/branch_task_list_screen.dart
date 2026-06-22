import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/cubit/task_state.dart';
import 'package:fbro/features/task/presentation/widgets/manager_task_card.dart';
import 'package:fbro/features/task/presentation/widgets/task_empty_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_template_sheets.dart';

/// The full task list for a single branch, with the manager/admin action set
/// (create / assign / edit / review / delete via [ManagerTaskCard]). Reads the
/// already-loaded [TaskCubit] stream and filters to [branchId] so it stays live
/// without a second query.
///
/// This is the **secondary** branch surface (reached via the Branch Operations
/// "All tasks" action and the admin branch overview drill) — the primary surface
/// is the operations cockpit. It also keeps **unassigned** tasks reachable, which
/// the employee-centric cockpit does not surface on its own.
class BranchTaskListScreen extends StatelessWidget {
  const BranchTaskListScreen({
    super.key,
    required this.branchId,
    required this.branchName,
    this.isAdmin = false,
  });

  final String branchId;
  final String branchName;
  final bool isAdmin;

  Future<void> _create(BuildContext context) => startNewTaskFlow(
        context: context,
        cubit: context.read<TaskCubit>(),
        // The branch is fixed in this context, so behave like a branch-scoped
        // form (no branch picker) regardless of role.
        isAdmin: false,
        defaultBranchId: branchId,
        templateBranchFilter: branchId,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('$branchName · All tasks', style: AppTypography.h3),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Task',
            style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
      ),
      body: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (tasks, busy, directory, _, _) =>
              _list(context, tasks, busy, directory),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<TaskEntity> all,
    bool busy,
    Map<String, UserEntity> directory,
  ) {
    final tasks = all.where((t) => (t.branchId ?? '') == branchId).toList();
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: tasks.isEmpty
              ? const TaskEmptyState(
                  icon: Icons.assignment_outlined,
                  message: 'No tasks in this branch yet.\nTap "New Task".',
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
                        child: ManagerTaskCard(
                          task: tasks[i],
                          directory: directory,
                          isAdmin: isAdmin,
                          defaultBranchId: branchId,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
