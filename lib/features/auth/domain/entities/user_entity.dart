import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/core/enums/user_role.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String uid,
    required String email,
    required String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    @Default(false) bool isEmailVerified,
    DateTime? createdAt,
    // ─── Roles & foundation (Phase 1) ───────────────────────────
    /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
    @Default(UserRole.employee) UserRole role,
    /// Store branch the user belongs to. Assigned by an admin; null until then.
    String? branchId,
    /// Soft-disable flag: a user can be deactivated without deletion.
    @Default(true) bool isActive,
    /// Shift assigned to the user (used from Phase 2 onward); null until then.
    String? assignedShift,
  }) = _UserEntity;
}
