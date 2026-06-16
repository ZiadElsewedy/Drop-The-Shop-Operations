// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_template_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TaskTemplateEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  TaskType get type => throw _privateConstructorUsedError;
  TaskPriority get priority => throw _privateConstructorUsedError;

  /// The reusable checklist (e.g. Unlock entrance · Turn on lights · …).
  List<ChecklistItemTemplate> get checklistItems =>
      throw _privateConstructorUsedError;

  /// Owning branch. Empty/null = a GLOBAL template (admin-made), available to
  /// every branch; otherwise scoped to that branch's managers/admins.
  String? get branchId => throw _privateConstructorUsedError;

  /// uid of the manager/admin who created the template.
  String? get createdBy => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of TaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskTemplateEntityCopyWith<TaskTemplateEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskTemplateEntityCopyWith<$Res> {
  factory $TaskTemplateEntityCopyWith(
    TaskTemplateEntity value,
    $Res Function(TaskTemplateEntity) then,
  ) = _$TaskTemplateEntityCopyWithImpl<$Res, TaskTemplateEntity>;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskType type,
    TaskPriority priority,
    List<ChecklistItemTemplate> checklistItems,
    String? branchId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$TaskTemplateEntityCopyWithImpl<$Res, $Val extends TaskTemplateEntity>
    implements $TaskTemplateEntityCopyWith<$Res> {
  _$TaskTemplateEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? type = null,
    Object? priority = null,
    Object? checklistItems = null,
    Object? branchId = freezed,
    Object? createdBy = freezed,
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
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as TaskType,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as TaskPriority,
            checklistItems: null == checklistItems
                ? _value.checklistItems
                : checklistItems // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistItemTemplate>,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$TaskTemplateEntityImplCopyWith<$Res>
    implements $TaskTemplateEntityCopyWith<$Res> {
  factory _$$TaskTemplateEntityImplCopyWith(
    _$TaskTemplateEntityImpl value,
    $Res Function(_$TaskTemplateEntityImpl) then,
  ) = __$$TaskTemplateEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskType type,
    TaskPriority priority,
    List<ChecklistItemTemplate> checklistItems,
    String? branchId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$TaskTemplateEntityImplCopyWithImpl<$Res>
    extends _$TaskTemplateEntityCopyWithImpl<$Res, _$TaskTemplateEntityImpl>
    implements _$$TaskTemplateEntityImplCopyWith<$Res> {
  __$$TaskTemplateEntityImplCopyWithImpl(
    _$TaskTemplateEntityImpl _value,
    $Res Function(_$TaskTemplateEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? type = null,
    Object? priority = null,
    Object? checklistItems = null,
    Object? branchId = freezed,
    Object? createdBy = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$TaskTemplateEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as TaskType,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as TaskPriority,
        checklistItems: null == checklistItems
            ? _value._checklistItems
            : checklistItems // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistItemTemplate>,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
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

class _$TaskTemplateEntityImpl extends _TaskTemplateEntity {
  const _$TaskTemplateEntityImpl({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.priority = TaskPriority.normal,
    final List<ChecklistItemTemplate> checklistItems =
        const <ChecklistItemTemplate>[],
    this.branchId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  }) : _checklistItems = checklistItems,
       super._();

  @override
  final String id;
  @override
  final String title;
  @override
  final String? description;
  @override
  @JsonKey()
  final TaskType type;
  @override
  @JsonKey()
  final TaskPriority priority;

  /// The reusable checklist (e.g. Unlock entrance · Turn on lights · …).
  final List<ChecklistItemTemplate> _checklistItems;

  /// The reusable checklist (e.g. Unlock entrance · Turn on lights · …).
  @override
  @JsonKey()
  List<ChecklistItemTemplate> get checklistItems {
    if (_checklistItems is EqualUnmodifiableListView) return _checklistItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklistItems);
  }

  /// Owning branch. Empty/null = a GLOBAL template (admin-made), available to
  /// every branch; otherwise scoped to that branch's managers/admins.
  @override
  final String? branchId;

  /// uid of the manager/admin who created the template.
  @override
  final String? createdBy;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'TaskTemplateEntity(id: $id, title: $title, description: $description, type: $type, priority: $priority, checklistItems: $checklistItems, branchId: $branchId, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskTemplateEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            const DeepCollectionEquality().equals(
              other._checklistItems,
              _checklistItems,
            ) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
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
    description,
    type,
    priority,
    const DeepCollectionEquality().hash(_checklistItems),
    branchId,
    createdBy,
    createdAt,
    updatedAt,
  );

  /// Create a copy of TaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskTemplateEntityImplCopyWith<_$TaskTemplateEntityImpl> get copyWith =>
      __$$TaskTemplateEntityImplCopyWithImpl<_$TaskTemplateEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _TaskTemplateEntity extends TaskTemplateEntity {
  const factory _TaskTemplateEntity({
    required final String id,
    required final String title,
    final String? description,
    final TaskType type,
    final TaskPriority priority,
    final List<ChecklistItemTemplate> checklistItems,
    final String? branchId,
    final String? createdBy,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$TaskTemplateEntityImpl;
  const _TaskTemplateEntity._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;
  @override
  TaskType get type;
  @override
  TaskPriority get priority;

  /// The reusable checklist (e.g. Unlock entrance · Turn on lights · …).
  @override
  List<ChecklistItemTemplate> get checklistItems;

  /// Owning branch. Empty/null = a GLOBAL template (admin-made), available to
  /// every branch; otherwise scoped to that branch's managers/admins.
  @override
  String? get branchId;

  /// uid of the manager/admin who created the template.
  @override
  String? get createdBy;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of TaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskTemplateEntityImplCopyWith<_$TaskTemplateEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
