import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/manager_task_card.dart';
import 'package:drop/features/task/presentation/widgets/task_empty_state.dart';

/// The third level of the operations hierarchy (Branch operations → here → Task
/// details). **Task-centric** by design — one employee's tasks grouped by
/// status. Reads the already-loaded [TaskCubit] stream (loaded by the cockpit)
/// and filters to this employee, so it stays live; tapping a card opens the full
/// [TaskDetailsScreen] (via [ManagerTaskCard]), where review/assign/edit live.
class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employee,
    required this.isAdmin,
    required this.defaultBranchId,
  });

  final UserEntity employee;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  Widget build(BuildContext context) {
    final name = (employee.displayName != null && employee.displayName!.isNotEmpty)
        ? employee.displayName!
        : employee.email;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar.fromUser(employee, size: 34),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: AppTypography.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(_capitalize(employee.role.value),
                      style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (tasks, busy, directory, _, _) =>
              _body(context, tasks, busy, directory),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<TaskEntity> all,
    bool busy,
    Map<String, UserEntity> directory,
  ) {
    final mine =
        all.where((t) => t.assigneeIds.contains(employee.uid)).toList();

    if (mine.isEmpty) {
      return const TaskEmptyState(
        message: 'No tasks assigned to this employee yet.',
      );
    }

    // Status groups in triage order: act-now → in-flight → backlog → waiting → done.
    final groups = <_Group>[
      _Group('Rework requested',
          mine.where((t) => t.status == TaskStatus.rejected).toList()),
      _Group('In progress',
          mine.where((t) => t.status == TaskStatus.started).toList()),
      _Group('Pending',
          mine.where((t) => t.status == TaskStatus.pending).toList()),
      _Group(
          'Submitted',
          mine
              .where((t) =>
                  t.status == TaskStatus.completed ||
                  t.status == TaskStatus.waitingReview)
              .toList()),
      _Group('Completed',
          mine.where((t) => t.status == TaskStatus.approved).toList()),
    ];

    var index = 0;
    final children = <Widget>[];
    for (final g in groups) {
      if (g.tasks.isEmpty) continue;
      children.add(_SectionHeader(label: g.label, count: g.tasks.length));
      for (final t in g.tasks) {
        children.add(EntranceFade(
          delay: staggerDelay(index++),
          child: ManagerTaskCard(
            task: t,
            directory: directory,
            isAdmin: isAdmin,
            defaultBranchId: defaultBranchId,
          ),
        ));
      }
    }

    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.lg,
              AppSpacing.pagePadding,
              AppSpacing.xxxl * 2,
            ),
            children: children,
          ),
        ),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Group {
  _Group(this.label, this.tasks);
  final String label;
  final List<TaskEntity> tasks;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 0.6)),
          const SizedBox(width: AppSpacing.sm),
          Text('$count',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
