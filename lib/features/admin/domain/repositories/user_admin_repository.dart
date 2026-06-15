import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';

/// Admin operations over users (Phase 5). Reuses the auth [UserEntity]. All
/// methods require an admin caller (enforced server-side).
abstract class UserAdminRepository {
  Future<List<UserEntity>> getAllUsers();
  Future<List<UserEntity>> getUsersByRole(UserRole role);
  Future<List<UserEntity>> getPendingUsers();

  /// Approve a pending user: approved + active, with the assigned role/branch.
  Future<void> approveUser({
    required String uid,
    required UserRole role,
    String? branchId,
  });

  /// Reject a pending user: rejected + inactive.
  Future<void> rejectUser(String uid);

  Future<void> setUserActive(String uid, bool isActive);
  Future<void> changeUserRole(String uid, UserRole role);
  Future<void> changeUserBranch(String uid, String? branchId);
}
