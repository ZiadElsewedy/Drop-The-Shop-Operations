// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcast_template_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BroadcastTemplateEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  BroadcastCategory get category => throw _privateConstructorUsedError;

  /// Who created the template.
  String get ownerId => throw _privateConstructorUsedError;

  /// Owning branch; null/empty = a global template.
  String? get branchId => throw _privateConstructorUsedError;
  bool get isFavorite => throw _privateConstructorUsedError;
  int get usageCount => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of BroadcastTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BroadcastTemplateEntityCopyWith<BroadcastTemplateEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BroadcastTemplateEntityCopyWith<$Res> {
  factory $BroadcastTemplateEntityCopyWith(
    BroadcastTemplateEntity value,
    $Res Function(BroadcastTemplateEntity) then,
  ) = _$BroadcastTemplateEntityCopyWithImpl<$Res, BroadcastTemplateEntity>;
  @useResult
  $Res call({
    String id,
    String title,
    String message,
    BroadcastCategory category,
    String ownerId,
    String? branchId,
    bool isFavorite,
    int usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$BroadcastTemplateEntityCopyWithImpl<
  $Res,
  $Val extends BroadcastTemplateEntity
>
    implements $BroadcastTemplateEntityCopyWith<$Res> {
  _$BroadcastTemplateEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BroadcastTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? message = null,
    Object? category = null,
    Object? ownerId = null,
    Object? branchId = freezed,
    Object? isFavorite = null,
    Object? usageCount = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as BroadcastCategory,
            ownerId: null == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                      as String,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            isFavorite: null == isFavorite
                ? _value.isFavorite
                : isFavorite // ignore: cast_nullable_to_non_nullable
                      as bool,
            usageCount: null == usageCount
                ? _value.usageCount
                : usageCount // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BroadcastTemplateEntityImplCopyWith<$Res>
    implements $BroadcastTemplateEntityCopyWith<$Res> {
  factory _$$BroadcastTemplateEntityImplCopyWith(
    _$BroadcastTemplateEntityImpl value,
    $Res Function(_$BroadcastTemplateEntityImpl) then,
  ) = __$$BroadcastTemplateEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String message,
    BroadcastCategory category,
    String ownerId,
    String? branchId,
    bool isFavorite,
    int usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$BroadcastTemplateEntityImplCopyWithImpl<$Res>
    extends
        _$BroadcastTemplateEntityCopyWithImpl<
          $Res,
          _$BroadcastTemplateEntityImpl
        >
    implements _$$BroadcastTemplateEntityImplCopyWith<$Res> {
  __$$BroadcastTemplateEntityImplCopyWithImpl(
    _$BroadcastTemplateEntityImpl _value,
    $Res Function(_$BroadcastTemplateEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcastTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? message = null,
    Object? category = null,
    Object? ownerId = null,
    Object? branchId = freezed,
    Object? isFavorite = null,
    Object? usageCount = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$BroadcastTemplateEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as BroadcastCategory,
        ownerId: null == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
                  as String,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        isFavorite: null == isFavorite
            ? _value.isFavorite
            : isFavorite // ignore: cast_nullable_to_non_nullable
                  as bool,
        usageCount: null == usageCount
            ? _value.usageCount
            : usageCount // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$BroadcastTemplateEntityImpl extends _BroadcastTemplateEntity {
  const _$BroadcastTemplateEntityImpl({
    required this.id,
    required this.title,
    required this.message,
    this.category = BroadcastCategory.announcement,
    this.ownerId = '',
    this.branchId,
    this.isFavorite = false,
    this.usageCount = 0,
    this.createdAt,
    this.updatedAt,
  }) : super._();

  @override
  final String id;
  @override
  final String title;
  @override
  final String message;
  @override
  @JsonKey()
  final BroadcastCategory category;

  /// Who created the template.
  @override
  @JsonKey()
  final String ownerId;

  /// Owning branch; null/empty = a global template.
  @override
  final String? branchId;
  @override
  @JsonKey()
  final bool isFavorite;
  @override
  @JsonKey()
  final int usageCount;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'BroadcastTemplateEntity(id: $id, title: $title, message: $message, category: $category, ownerId: $ownerId, branchId: $branchId, isFavorite: $isFavorite, usageCount: $usageCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BroadcastTemplateEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.isFavorite, isFavorite) ||
                other.isFavorite == isFavorite) &&
            (identical(other.usageCount, usageCount) ||
                other.usageCount == usageCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    message,
    category,
    ownerId,
    branchId,
    isFavorite,
    usageCount,
    createdAt,
    updatedAt,
  );

  /// Create a copy of BroadcastTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BroadcastTemplateEntityImplCopyWith<_$BroadcastTemplateEntityImpl>
  get copyWith =>
      __$$BroadcastTemplateEntityImplCopyWithImpl<
        _$BroadcastTemplateEntityImpl
      >(this, _$identity);
}

abstract class _BroadcastTemplateEntity extends BroadcastTemplateEntity {
  const factory _BroadcastTemplateEntity({
    required final String id,
    required final String title,
    required final String message,
    final BroadcastCategory category,
    final String ownerId,
    final String? branchId,
    final bool isFavorite,
    final int usageCount,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$BroadcastTemplateEntityImpl;
  const _BroadcastTemplateEntity._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String get message;
  @override
  BroadcastCategory get category;

  /// Who created the template.
  @override
  String get ownerId;

  /// Owning branch; null/empty = a global template.
  @override
  String? get branchId;
  @override
  bool get isFavorite;
  @override
  int get usageCount;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of BroadcastTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BroadcastTemplateEntityImplCopyWith<_$BroadcastTemplateEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}
