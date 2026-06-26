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
  Future<String> createAccount({
    required String name,
    required String email,
    required String temporaryPassword,
    required UserRole role,
    String? branchId,
    String? assignedShift,
    String? position,
  }) async {
    try {
      return await _remote.createAccount(
        name: name,
        email: email,
        password: temporaryPassword,
        role: role.value,
        branchId: branchId,
        assignedShift: assignedShift,
        position: position,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> resetPassword({
    required String uid,
    required String temporaryPassword,
  }) =>
      _run(() => _remote.resetPassword(uid: uid, tempPassword: temporaryPassword));

  @override
  Future<void> setUserActive(String uid, bool isActive) =>
      _run(() => _remote.updateUser(uid, {'isActive': isActive}));

  @override
  Future<void> changeUserRole(String uid, UserRole role) =>
      _run(() => _remote.updateUser(uid, {'role': role.value}));

  @override
  Future<void> changeUserBranch(String uid, String? branchId) =>
      _run(() => _remote.updateUser(uid, {'branchId': branchId}));

  @override
  Future<void> changeUserPosition(String uid, String? position) =>
      _run(() => _remote.updateUser(uid, {'position': position}));

  @override
  Future<void> changeUserEmploymentStatus(String uid, String status) =>
      _run(() => _remote.updateUser(uid, {'employmentStatus': status}));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
