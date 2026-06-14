import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/enums/approval_status.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final String authProvider;
  final bool isEmailVerified;
  final DateTime? createdAt;
  // ─── Roles & foundation (Phase 1) ───────────────────────────
  final UserRole role;
  final String? branchId;
  final bool isActive;
  final String? assignedShift;
  // ─── Approval (account activation) ──────────────────────────
  final ApprovalStatus approvalStatus;

  const UserModel({
    required this.uid,
    required this.email,
    required this.authProvider,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.createdAt,
    this.role = UserRole.employee,
    this.branchId,
    this.isActive = true,
    this.assignedShift,
    this.approvalStatus = ApprovalStatus.approved,
  });

  factory UserModel.fromFirebaseUser(User user, {String authProvider = 'unknown'}) =>
      UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        phoneNumber: user.phoneNumber,
        authProvider: authProvider,
        isEmailVerified: user.emailVerified,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        uid: entity.uid,
        email: entity.email,
        displayName: entity.displayName,
        photoUrl: entity.photoUrl,
        phoneNumber: entity.phoneNumber,
        authProvider: entity.authProvider,
        isEmailVerified: entity.isEmailVerified,
        createdAt: entity.createdAt,
        role: entity.role,
        branchId: entity.branchId,
        isActive: entity.isActive,
        assignedShift: entity.assignedShift,
        approvalStatus: entity.approvalStatus,
      );

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String,
        email: map['email'] as String,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        authProvider: map['authProvider'] as String? ?? 'unknown',
        isEmailVerified: map['isEmailVerified'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        role: UserRole.fromString(map['role'] as String?),
        branchId: map['branchId'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        assignedShift: map['assignedShift'] as String?,
        approvalStatus: ApprovalStatus.fromString(map['approvalStatus'] as String?),
      );

  /// Identity/auth fields written on every sign-in (merge). The privileged
  /// fields (`role`, `branchId`, `isActive`, `assignedShift`, `approvalStatus`)
  /// are intentionally EXCLUDED here so a routine re-login can never overwrite an
  /// admin-assigned role/branch or re-pend an approved account. Those are seeded
  /// once on first document creation — see [UserRemoteDataSourceImpl.saveUser].
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'authProvider': authProvider,
        'isEmailVerified': isEmailVerified,
      };

  UserEntity toEntity() => UserEntity(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        authProvider: authProvider,
        isEmailVerified: isEmailVerified,
        createdAt: createdAt,
        role: role,
        branchId: branchId,
        isActive: isActive,
        assignedShift: assignedShift,
        approvalStatus: approvalStatus,
      );
}
