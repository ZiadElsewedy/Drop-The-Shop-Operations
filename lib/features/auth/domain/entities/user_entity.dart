import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/enums/approval_status.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const UserEntity._();

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
    // ─── Approval (account activation) ──────────────────────────
    /// Where the account sits in the approval lifecycle. New self-registrations
    /// start [ApprovalStatus.pending]; a manager/admin approves them. Defaults to
    /// [ApprovalStatus.approved] so legacy documents are never locked out.
    @Default(ApprovalStatus.approved) ApprovalStatus approvalStatus,
  }) = _UserEntity;

  /// Whether the account has been approved by a manager/admin.
  bool get isApproved => approvalStatus.isApproved;

  /// Whether the user may enter the app: approved **and** active. Unapproved or
  /// deactivated users are confined to the Pending Approval screen by the router.
  bool get hasAppAccess => isApproved && isActive;
}
