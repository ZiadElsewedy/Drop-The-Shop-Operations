import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/operations/domain/branch_summary.dart';
import 'package:fbro/features/operations/domain/branch_workload.dart';
import 'package:fbro/features/operations/domain/shift_filter.dart';
import 'package:fbro/features/operations/presentation/cubit/branch_operations_cubit.dart';
import 'package:fbro/features/operations/presentation/cubit/branch_operations_state.dart';
import 'package:fbro/features/operations/presentation/pages/employee_detail_screen.dart';
import 'package:fbro/features/operations/presentation/widgets/workload_card.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/pages/branch_task_list_screen.dart';
import 'package:fbro/features/task/presentation/widgets/task_template_sheets.dart';

/// The Branch Operations cockpit — the heart of the task→operations redesign.
/// One scannable surface that answers a manager/admin's real questions about a
/// branch (who's overloaded? what's overdue? what's awaiting review?) in
/// seconds: a four-stat summary header, an instant shift lens, and
/// overload-first employee workload cards. Tasks live *inside* here (drill into
/// an employee, or "All tasks") — there is no standalone task list destination.
///
/// Shared by manager (their own branch — reached from the nav) and admin (any
/// branch — reached from the branch overview drill). Display is driven by
/// [BranchOperationsCubit] (read/derive); writes flow through [TaskCubit], which
/// is also loaded here so downstream task screens stay live.
class BranchOperationsScreen extends StatefulWidget {
  const BranchOperationsScreen({
    super.key,
    required this.branchId,
    this.branchName,
  });

  final String branchId;
  final String? branchName;

  @override
  State<BranchOperationsScreen> createState() => _BranchOperationsScreenState();
}

class _BranchOperationsScreenState extends State<BranchOperationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    context
        .read<BranchOperationsCubit>()
        .load(widget.branchId, branchName: widget.branchName);
    // Load the task workflow stream too, so the employee drill-down, Task
    // Details actions and the "All tasks" list are live + writable here.
    final user = context.currentUser;
    if (user != null) context.read<TaskCubit>().load(user);
  }

  String get _branchLabel => widget.branchName ?? 'Branch operations';

  Future<void> _newTask() => startNewTaskFlow(
        context: context,
        cubit: context.read<TaskCubit>(),
        // Branch is fixed to this cockpit's branch for both roles.
        isAdmin: false,
        defaultBranchId: widget.branchId,
        templateBranchFilter: widget.branchId,
      );

  void _openAllTasks() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BranchTaskListScreen(
          branchId: widget.branchId,
          branchName: widget.branchName ?? 'Branch',
          isAdmin: context.isAdmin,
        ),
      ));

  void _openEmployee(UserEntity employee) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(
          employee: employee,
          isAdmin: context.isAdmin,
          defaultBranchId: widget.branchId,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text(_branchLabel, style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rounded,
                color: AppColors.textSecondary),
            tooltip: 'All tasks',
            onPressed: _openAllTasks,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => context.read<BranchOperationsCubit>().refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTask,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Task',
            style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
      ),
      body: BlocConsumer<BranchOperationsCubit, BranchOperationsState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (branchId, workload, filter, branchName, directory) =>
              _cockpit(workload, filter),
          error: (m) => _ErrorState(
            message: m,
            onRetry: () => context.read<BranchOperationsCubit>().refresh(),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _cockpit(BranchWorkload workload, ShiftFilter filter) {
    final employees = workload.employees;
    return RefreshIndicator(
      onRefresh: () => context.read<BranchOperationsCubit>().refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl * 2,
        ),
        children: [
          _SummaryHeader(summary: workload.summary),
          const SizedBox(height: AppSpacing.xl),
          _ShiftToggle(
            value: filter,
            onChanged: (f) => context.read<BranchOperationsCubit>().setFilter(f),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(filter: filter, count: employees.length),
          const SizedBox(height: AppSpacing.md),
          if (employees.isEmpty)
            _EmptyTeam(filter: filter)
          else
            for (var i = 0; i < employees.length; i++)
              EntranceFade(
                delay: staggerDelay(i),
                child: WorkloadCard(
                  workload: employees[i],
                  onTap: () => _openEmployee(employees[i].user),
                ),
              ),
        ],
      ),
    );
  }
}

// ─── Summary header (branch health in 3 seconds) ──────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary});
  final BranchSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    value: summary.activeTasks, label: 'Active tasks')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: _StatTile(
                    value: summary.overdueTasks,
                    label: 'Overdue',
                    alert: summary.overdueTasks > 0)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    value: summary.pendingReviews, label: 'Pending review')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child:
                    _StatTile(value: summary.staffActive, label: 'Staff active')),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.alert = false});
  final int value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
            color: alert ? AppColors.error.withAlpha(90) : AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppTypography.h1.copyWith(
              fontSize: 26,
              color: alert ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

// ─── Shift lens (a toggle, never a screen) ────────────────────────────────────

class _ShiftToggle extends StatelessWidget {
  const _ShiftToggle({required this.value, required this.onChanged});
  final ShiftFilter value;
  final ValueChanged<ShiftFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          for (final f in ShiftFilter.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == f ? AppColors.primary : AppColors.transparent,
                    borderRadius: AppRadius.smAll,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    f.label,
                    style: AppTypography.label.copyWith(
                      color: value == f
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.filter, required this.count});
  final ShiftFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = filter == ShiftFilter.all
        ? 'TEAM · $count'
        : '${filter.label.toUpperCase()} · $count ON SHIFT';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary, letterSpacing: 0.6)),
        Text('overload first', style: AppTypography.caption),
      ],
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam({required this.filter});
  final ShiftFilter filter;

  @override
  Widget build(BuildContext context) {
    final msg = filter == ShiftFilter.all
        ? 'No active employees in this branch yet.'
        : 'No one is on the ${filter.label.toLowerCase()} shift today.';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined,
              color: AppColors.textTertiary, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(msg, style: AppTypography.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: AppTypography.label
                      .copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
