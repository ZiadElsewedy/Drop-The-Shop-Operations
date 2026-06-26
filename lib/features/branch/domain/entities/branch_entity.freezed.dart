// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branch_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BranchEntity {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;

  /// Optional area / address label.
  String? get location => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  /// Branch **logo** (square mark) — Storage `branches/{id}/logo.jpg`. Drives
  /// [BranchAvatar]; null falls back to initials. (§8 Branch Media.)
  String? get logoUrl => throw _privateConstructorUsedError;

  /// Branch **cover** banner — Storage `branches/{id}/cover.jpg`. Null = none.
  String? get coverUrl => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Soft-delete marker; null while the branch is live.
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Optional branch-level shift-swap rules (role compatibility, rest hours).
  /// Null = [SwapPolicy.permissive] (any role can swap, no rest rule). Stored
  /// as a nested map under `swapPolicy`.
  SwapPolicy? get swapPolicy => throw _privateConstructorUsedError;

  /// Create a copy of BranchEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BranchEntityCopyWith<BranchEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BranchEntityCopyWith<$Res> {
  factory $BranchEntityCopyWith(
    BranchEntity value,
    $Res Function(BranchEntity) then,
  ) = _$BranchEntityCopyWithImpl<$Res, BranchEntity>;
  @useResult
  $Res call({
    String id,
    String name,
    String? location,
    bool isActive,
    String? logoUrl,
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SwapPolicy? swapPolicy,
  });
}

/// @nodoc
class _$BranchEntityCopyWithImpl<$Res, $Val extends BranchEntity>
    implements $BranchEntityCopyWith<$Res> {
  _$BranchEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BranchEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? location = freezed,
    Object? isActive = null,
    Object? logoUrl = freezed,
    Object? coverUrl = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? deletedAt = freezed,
    Object? swapPolicy = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            location: freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            logoUrl: freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverUrl: freezed == coverUrl
                ? _value.coverUrl
                : coverUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            swapPolicy: freezed == swapPolicy
                ? _value.swapPolicy
                : swapPolicy // ignore: cast_nullable_to_non_nullable
                      as SwapPolicy?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BranchEntityImplCopyWith<$Res>
    implements $BranchEntityCopyWith<$Res> {
  factory _$$BranchEntityImplCopyWith(
    _$BranchEntityImpl value,
    $Res Function(_$BranchEntityImpl) then,
  ) = __$$BranchEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? location,
    bool isActive,
    String? logoUrl,
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SwapPolicy? swapPolicy,
  });
}

/// @nodoc
class __$$BranchEntityImplCopyWithImpl<$Res>
    extends _$BranchEntityCopyWithImpl<$Res, _$BranchEntityImpl>
    implements _$$BranchEntityImplCopyWith<$Res> {
  __$$BranchEntityImplCopyWithImpl(
    _$BranchEntityImpl _value,
    $Res Function(_$BranchEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BranchEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? location = freezed,
    Object? isActive = null,
    Object? logoUrl = freezed,
    Object? coverUrl = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? deletedAt = freezed,
    Object? swapPolicy = freezed,
  }) {
    return _then(
      _$BranchEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        location: freezed == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        logoUrl: freezed == logoUrl
            ? _value.logoUrl
            : logoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _value.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        swapPolicy: freezed == swapPolicy
            ? _value.swapPolicy
            : swapPolicy // ignore: cast_nullable_to_non_nullable
                  as SwapPolicy?,
      ),
    );
  }
}

/// @nodoc

class _$BranchEntityImpl extends _BranchEntity {
  const _$BranchEntityImpl({
    required this.id,
    required this.name,
    this.location,
    this.isActive = true,
    this.logoUrl,
    this.coverUrl,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.swapPolicy,
  }) : super._();

  @override
  final String id;
  @override
  final String name;

  /// Optional area / address label.
  @override
  final String? location;
  @override
  @JsonKey()
  final bool isActive;

  /// Branch **logo** (square mark) — Storage `branches/{id}/logo.jpg`. Drives
  /// [BranchAvatar]; null falls back to initials. (§8 Branch Media.)
  @override
  final String? logoUrl;

  /// Branch **cover** banner — Storage `branches/{id}/cover.jpg`. Null = none.
  @override
  final String? coverUrl;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  /// Soft-delete marker; null while the branch is live.
  @override
  final DateTime? deletedAt;

  /// Optional branch-level shift-swap rules (role compatibility, rest hours).
  /// Null = [SwapPolicy.permissive] (any role can swap, no rest rule). Stored
  /// as a nested map under `swapPolicy`.
  @override
  final SwapPolicy? swapPolicy;

  @override
  String toString() {
    return 'BranchEntity(id: $id, name: $name, location: $location, isActive: $isActive, logoUrl: $logoUrl, coverUrl: $coverUrl, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt, swapPolicy: $swapPolicy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BranchEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.swapPolicy, swapPolicy) ||
                other.swapPolicy == swapPolicy));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    location,
    isActive,
    logoUrl,
    coverUrl,
    createdAt,
    updatedAt,
    deletedAt,
    swapPolicy,
  );

  /// Create a copy of BranchEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BranchEntityImplCopyWith<_$BranchEntityImpl> get copyWith =>
      __$$BranchEntityImplCopyWithImpl<_$BranchEntityImpl>(this, _$identity);
}

abstract class _BranchEntity extends BranchEntity {
  const factory _BranchEntity({
    required final String id,
    required final String name,
    final String? location,
    final bool isActive,
    final String? logoUrl,
    final String? coverUrl,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? deletedAt,
    final SwapPolicy? swapPolicy,
  }) = _$BranchEntityImpl;
  const _BranchEntity._() : super._();

  @override
  String get id;
  @override
  String get name;

  /// Optional area / address label.
  @override
  String? get location;
  @override
  bool get isActive;

  /// Branch **logo** (square mark) — Storage `branches/{id}/logo.jpg`. Drives
  /// [BranchAvatar]; null falls back to initials. (§8 Branch Media.)
  @override
  String? get logoUrl;

  /// Branch **cover** banner — Storage `branches/{id}/cover.jpg`. Null = none.
  @override
  String? get coverUrl;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Soft-delete marker; null while the branch is live.
  @override
  DateTime? get deletedAt;

  /// Optional branch-level shift-swap rules (role compatibility, rest hours).
  /// Null = [SwapPolicy.permissive] (any role can swap, no rest rule). Stored
  /// as a nested map under `swapPolicy`.
  @override
  SwapPolicy? get swapPolicy;

  /// Create a copy of BranchEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BranchEntityImplCopyWith<_$BranchEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
