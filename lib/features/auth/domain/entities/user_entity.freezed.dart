// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$UserEntity {
  String get uid => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get authProvider => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;
  bool get isEmailVerified => throw _privateConstructorUsedError;
  DateTime? get createdAt =>
      throw _privateConstructorUsedError; // ─── Roles & foundation (Phase 1) ───────────────────────────
  /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
  UserRole get role => throw _privateConstructorUsedError;

  /// Store branch the user belongs to. Assigned by an admin; null until then.
  String? get branchId => throw _privateConstructorUsedError;

  /// Soft-disable flag: a user can be deactivated without deletion.
  bool get isActive => throw _privateConstructorUsedError;

  /// Shift assigned to the user (used from Phase 2 onward); null until then.
  String? get assignedShift => throw _privateConstructorUsedError;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserEntityCopyWith<UserEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserEntityCopyWith<$Res> {
  factory $UserEntityCopyWith(
    UserEntity value,
    $Res Function(UserEntity) then,
  ) = _$UserEntityCopyWithImpl<$Res, UserEntity>;
  @useResult
  $Res call({
    String uid,
    String email,
    String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    bool isEmailVerified,
    DateTime? createdAt,
    UserRole role,
    String? branchId,
    bool isActive,
    String? assignedShift,
  });
}

/// @nodoc
class _$UserEntityCopyWithImpl<$Res, $Val extends UserEntity>
    implements $UserEntityCopyWith<$Res> {
  _$UserEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? authProvider = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? phoneNumber = freezed,
    Object? isEmailVerified = null,
    Object? createdAt = freezed,
    Object? role = null,
    Object? branchId = freezed,
    Object? isActive = null,
    Object? assignedShift = freezed,
  }) {
    return _then(
      _value.copyWith(
            uid: null == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            authProvider: null == authProvider
                ? _value.authProvider
                : authProvider // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            phoneNumber: freezed == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            isEmailVerified: null == isEmailVerified
                ? _value.isEmailVerified
                : isEmailVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            assignedShift: freezed == assignedShift
                ? _value.assignedShift
                : assignedShift // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserEntityImplCopyWith<$Res>
    implements $UserEntityCopyWith<$Res> {
  factory _$$UserEntityImplCopyWith(
    _$UserEntityImpl value,
    $Res Function(_$UserEntityImpl) then,
  ) = __$$UserEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String uid,
    String email,
    String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    bool isEmailVerified,
    DateTime? createdAt,
    UserRole role,
    String? branchId,
    bool isActive,
    String? assignedShift,
  });
}

/// @nodoc
class __$$UserEntityImplCopyWithImpl<$Res>
    extends _$UserEntityCopyWithImpl<$Res, _$UserEntityImpl>
    implements _$$UserEntityImplCopyWith<$Res> {
  __$$UserEntityImplCopyWithImpl(
    _$UserEntityImpl _value,
    $Res Function(_$UserEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? authProvider = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? phoneNumber = freezed,
    Object? isEmailVerified = null,
    Object? createdAt = freezed,
    Object? role = null,
    Object? branchId = freezed,
    Object? isActive = null,
    Object? assignedShift = freezed,
  }) {
    return _then(
      _$UserEntityImpl(
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        authProvider: null == authProvider
            ? _value.authProvider
            : authProvider // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        phoneNumber: freezed == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        isEmailVerified: null == isEmailVerified
            ? _value.isEmailVerified
            : isEmailVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        assignedShift: freezed == assignedShift
            ? _value.assignedShift
            : assignedShift // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$UserEntityImpl implements _UserEntity {
  const _$UserEntityImpl({
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
  });

  @override
  final String uid;
  @override
  final String email;
  @override
  final String authProvider;
  @override
  final String? displayName;
  @override
  final String? photoUrl;
  @override
  final String? phoneNumber;
  @override
  @JsonKey()
  final bool isEmailVerified;
  @override
  final DateTime? createdAt;
  // ─── Roles & foundation (Phase 1) ───────────────────────────
  /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
  @override
  @JsonKey()
  final UserRole role;

  /// Store branch the user belongs to. Assigned by an admin; null until then.
  @override
  final String? branchId;

  /// Soft-disable flag: a user can be deactivated without deletion.
  @override
  @JsonKey()
  final bool isActive;

  /// Shift assigned to the user (used from Phase 2 onward); null until then.
  @override
  final String? assignedShift;

  @override
  String toString() {
    return 'UserEntity(uid: $uid, email: $email, authProvider: $authProvider, displayName: $displayName, photoUrl: $photoUrl, phoneNumber: $phoneNumber, isEmailVerified: $isEmailVerified, createdAt: $createdAt, role: $role, branchId: $branchId, isActive: $isActive, assignedShift: $assignedShift)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserEntityImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.authProvider, authProvider) ||
                other.authProvider == authProvider) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.isEmailVerified, isEmailVerified) ||
                other.isEmailVerified == isEmailVerified) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.assignedShift, assignedShift) ||
                other.assignedShift == assignedShift));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    uid,
    email,
    authProvider,
    displayName,
    photoUrl,
    phoneNumber,
    isEmailVerified,
    createdAt,
    role,
    branchId,
    isActive,
    assignedShift,
  );

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserEntityImplCopyWith<_$UserEntityImpl> get copyWith =>
      __$$UserEntityImplCopyWithImpl<_$UserEntityImpl>(this, _$identity);
}

abstract class _UserEntity implements UserEntity {
  const factory _UserEntity({
    required final String uid,
    required final String email,
    required final String authProvider,
    final String? displayName,
    final String? photoUrl,
    final String? phoneNumber,
    final bool isEmailVerified,
    final DateTime? createdAt,
    final UserRole role,
    final String? branchId,
    final bool isActive,
    final String? assignedShift,
  }) = _$UserEntityImpl;

  @override
  String get uid;
  @override
  String get email;
  @override
  String get authProvider;
  @override
  String? get displayName;
  @override
  String? get photoUrl;
  @override
  String? get phoneNumber;
  @override
  bool get isEmailVerified;
  @override
  DateTime? get createdAt; // ─── Roles & foundation (Phase 1) ───────────────────────────
  /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
  @override
  UserRole get role;

  /// Store branch the user belongs to. Assigned by an admin; null until then.
  @override
  String? get branchId;

  /// Soft-disable flag: a user can be deactivated without deletion.
  @override
  bool get isActive;

  /// Shift assigned to the user (used from Phase 2 onward); null until then.
  @override
  String? get assignedShift;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserEntityImplCopyWith<_$UserEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
