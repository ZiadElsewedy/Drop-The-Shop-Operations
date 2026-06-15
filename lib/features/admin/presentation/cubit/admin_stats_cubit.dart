import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/admin/domain/entities/admin_stats.dart';
import 'package:fbro/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';
import 'admin_stats_state.dart';

/// Computes the admin reports overview (Phase 5) by aggregating counts from the
/// branch, user and task repositories. Simple totals only.
class AdminStatsCubit extends Cubit<AdminStatsState> {
  final BranchRepository _branches;
  final UserAdminRepository _users;
  final TaskRepository _tasks;

  AdminStatsCubit(this._branches, this._users, this._tasks)
      : super(const AdminStatsState.initial());

  Future<void> load() async {
    emit(const AdminStatsState.loading());
    try {
      final branches = await _branches.getBranches();
      final users = await _users.getAllUsers();
      final tasks = await _tasks.getAllTasks();

      emit(AdminStatsState.loaded(AdminStats(
        totalBranches: branches.length,
        totalManagers: users.where((u) => u.role.isManager).length,
        totalEmployees: users.where((u) => u.role.isEmployee).length,
        pendingApprovals: users.where((u) => u.approvalStatus.isPending).length,
        // Active = anywhere in the pipeline before a terminal review outcome.
        activeTasks: tasks
            .where((t) => !t.status.isApproved && !t.status.isRejected)
            .length,
        // Completed = approved (the workflow's done state).
        completedTasks: tasks.where((t) => t.status.isApproved).length,
      )));
    } on Failure catch (e) {
      emit(AdminStatsState.error(e.message));
    } catch (_) {
      emit(const AdminStatsState.error('Failed to load dashboard stats.'));
    }
  }
}
