import 'package:fbro/core/enums/approval_status.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/admin/data/datasources/user_admin_remote_datasource.dart';
import 'package:fbro/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';

class UserAdminRepositoryImpl implements UserAdminRepository {
  final UserAdminRemoteDataSource _remote;

  UserAdminRepositoryImpl(this._remote);

  @override
  Future<List<UserEntity>> getAllUsers() async {
    try {
      final models = await _remote.getAllUsers();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<UserEntity>> getUsersByRole(UserRole role) async {
    try {
      final models = await _remote.getUsersByRole(role.value);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<UserEntity>> getPendingUsers() async {
    try {
      final models = await _remote.getPendingUsers();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> approveUser({
    required String uid,
    required UserRole role,
    String? branchId,
  }) =>
      _run(() => _remote.updateUser(uid, {
            'approvalStatus': ApprovalStatus.approved.value,
            'isActive': true,
            'role': role.value,
            'branchId': branchId,
          }));

  @override
  Future<void> rejectUser(String uid) => _run(() => _remote.updateUser(uid, {
        'approvalStatus': ApprovalStatus.rejected.value,
        'isActive': false,
      }));

  @override
  Future<void> setUserActive(String uid, bool isActive) =>
      _run(() => _remote.updateUser(uid, {'isActive': isActive}));

  @override
  Future<void> changeUserRole(String uid, UserRole role) =>
      _run(() => _remote.updateUser(uid, {'role': role.value}));

  @override
  Future<void> changeUserBranch(String uid, String? branchId) =>
      _run(() => _remote.updateUser(uid, {'branchId': branchId}));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
