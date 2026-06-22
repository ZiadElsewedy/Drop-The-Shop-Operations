import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';
import 'admin_users_state.dart';

/// Which slice of users a screen is showing.
enum AdminUserFilter { pending, managers, employees }

/// Admin user management (Phase 5) — backs the Pending Approvals, Managers and
/// Employees screens. Calls the repositories directly (no use-case layer in the
/// admin module). Also exposes [branches]/[promotableEmployees] for the pickers.
class AdminUsersCubit extends Cubit<AdminUsersState> {
  final UserAdminRepository _users;
  final BranchRepository _branches;

  AdminUserFilter _filter = AdminUserFilter.pending;

  AdminUsersCubit(this._users, this._branches)
      : super(const AdminUsersState.initial());

  List<UserEntity> get _current =>
      state.maybeWhen(loaded: (u, _) => u, orElse: () => const []);

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  Future<void> load(AdminUserFilter filter) async {
    _filter = filter;
    emit(const AdminUsersState.loading());
    try {
      emit(AdminUsersState.loaded(await _fetch(filter)));
    } on Failure catch (e) {
      emit(AdminUsersState.error(e.message));
    } catch (_) {
      emit(const AdminUsersState.error('Failed to load users.'));
    }
  }

  Future<void> refresh() => load(_filter);

  Future<List<UserEntity>> _fetch(AdminUserFilter filter) {
    switch (filter) {
      case AdminUserFilter.pending:
        return _users.getPendingUsers();
      case AdminUserFilter.managers:
        return _users.getUsersByRole(UserRole.manager);
      case AdminUserFilter.employees:
        return _users.getUsersByRole(UserRole.employee);
    }
  }

  // ─── Actions ───────────────────────────────────────────────────
  Future<void> approve(UserEntity user,
          {required UserRole role, String? branchId}) =>
      _mutate(() =>
          _users.approveUser(uid: user.uid, role: role, branchId: branchId));

  Future<void> reject(UserEntity user) =>
      _mutate(() => _users.rejectUser(user.uid));

  Future<void> setActive(UserEntity user, bool isActive) =>
      _mutate(() => _users.setUserActive(user.uid, isActive));

  Future<void> changeBranch(UserEntity user, String? branchId) =>
      _mutate(() => _users.changeUserBranch(user.uid, branchId));

  Future<void> changeRole(UserEntity user, UserRole role) =>
      _mutate(() => _users.changeUserRole(user.uid, role));

  /// Promote an employee to manager (the no-Auth-account-creation path: managers
  /// are promoted from existing approved users). Pass [branchId] to move them to a
  /// branch; when omitted the employee's **existing** branch is preserved — so a
  /// promoted manager is never left branch-less (which would block all branch
  /// schedule/task management). Admins can still reassign from the manager list.
  Future<void> promoteToManager(UserEntity user, {String? branchId}) =>
      _mutate(() async {
        await _users.changeUserRole(user.uid, UserRole.manager);
        if (branchId != null) {
          await _users.changeUserBranch(user.uid, branchId);
        }
      });

  // ─── Picker data ───────────────────────────────────────────────
  Future<List<BranchEntity>> branches() async {
    try {
      final list = await _branches.getBranches();
      return list.where((b) => b.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Approved employees that can be promoted to manager.
  Future<List<UserEntity>> promotableEmployees() async {
    try {
      final list = await _users.getUsersByRole(UserRole.employee);
      return list.where((u) => u.isApproved).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Read-only fetch of users by [role] (does not touch the list state) — used
  /// by the Branches page to resolve each branch's manager + employee count.
  Future<List<UserEntity>> usersWithRole(UserRole role) async {
    try {
      return await _users.getUsersByRole(role);
    } catch (_) {
      return const [];
    }
  }

  /// Read-only fetch of users awaiting approval (does not touch the list state)
  /// — used by the Admin Home "Pending approvals" section, which must not
  /// override whatever slice another screen has loaded into the shared cubit.
  Future<List<UserEntity>> pendingUsers() async {
    try {
      return await _users.getPendingUsers();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = _current;
    emit(AdminUsersState.loaded(prev, busy: true));
    try {
      await action();
      emit(AdminUsersState.loaded(await _fetch(_filter)));
    } on Failure catch (e) {
      emit(AdminUsersState.error(e.message));
      emit(AdminUsersState.loaded(prev));
    } catch (_) {
      emit(const AdminUsersState.error('Something went wrong. Please try again.'));
      emit(AdminUsersState.loaded(prev));
    }
  }
}
