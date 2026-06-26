import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/core/enums/user_role.dart';

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
    /// Home / mailing address. Optional contact detail an admin can fill in or
    /// edit at any time (also collected during profile onboarding).
    String? address,
    /// Emergency contact (name/phone). Optional contact detail an admin can fill
    /// in or edit at any time (also collected during profile onboarding).
    String? emergencyContact,
    @Default(false) bool isEmailVerified,
    DateTime? createdAt,
    // ─── Roles & foundation (Phase 1) ───────────────────────────
    /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
    @Default(UserRole.employee) UserRole role,
    /// Store branch the user belongs to. Assigned by an admin; null until then.
    String? branchId,
    /// Soft-disable flag: an admin can deactivate a user without deletion. This is
    /// the SINGLE access gate — a deactivated account is blocked at login.
    @Default(true) bool isActive,
    /// Shift assigned to the user; null until an admin sets it.
    String? assignedShift,
    /// Job position / role title within the branch (e.g. "Cashier",
    /// "Supervisor"). Optional — null means unspecified. Drives shift-swap role
    /// compatibility when a branch enables `SwapPolicy.restrictToSamePosition`
    /// (an unset position stays compatible with everyone).
    String? position,
    // ─── Account provisioning (admin-created, no self-registration) ─────
    /// True until the user changes the admin-issued temporary password. While
    /// set, the router confines them to the Force Password Change screen.
    @Default(false) bool mustChangePassword,
    /// True once the user has filled their onboarding profile. While false, the
    /// router confines them to the Profile Completion screen. Defaults true so
    /// legacy / pre-migration documents are never trapped in onboarding.
    @Default(true) bool isProfileCompleted,
    /// HR employment label (`active` / `suspended` / `terminated`). A record
    /// field shown/edited in admin — it does NOT gate access (that's [isActive]).
    @Default('active') String employmentStatus,
    /// The admin uid that provisioned this account (audit). Null for accounts
    /// created out of band (e.g. the bootstrapped first admin).
    String? createdBy,
  }) = _UserEntity;

  /// Whether the user may enter the app. DROP is admin-provisioned: the only
  /// access gate is [isActive] — a deactivated account is blocked at login and
  /// signed out. (`employmentStatus` is an HR label, not a gate.)
  bool get hasAppAccess => isActive;
}
