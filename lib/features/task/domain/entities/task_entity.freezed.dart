// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TaskEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  TaskType get type => throw _privateConstructorUsedError;
  TaskStatus get status => throw _privateConstructorUsedError;
  TaskPriority get priority => throw _privateConstructorUsedError;

  /// Owning branch (admin: any · manager: own branch).
  String? get branchId => throw _privateConstructorUsedError;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  List<String> get assigneeIds => throw _privateConstructorUsedError;

  /// Checklist the employee must work through (generated from a template).
  List<ChecklistItem> get checklist => throw _privateConstructorUsedError;

  /// uid of the manager/admin who created the task.
  String? get createdBy => throw _privateConstructorUsedError;

  /// Optional shift this task belongs to (references `shifts/{shiftId}`).
  String? get assignedShiftId => throw _privateConstructorUsedError;
  DateTime? get deadline => throw _privateConstructorUsedError;

  /// Free-text notes added by the executing employee.
  String? get notes => throw _privateConstructorUsedError;

  /// Download URL of the proof image the employee uploads on completion.
  String? get proofImageUrl =>
      throw _privateConstructorUsedError; // ─── Review audit (Phase 4 — lightweight, not a full history) ───
  /// uid of the manager/admin who approved the task, + when.
  String? get approvedBy => throw _privateConstructorUsedError;
  DateTime? get approvedAt => throw _privateConstructorUsedError;

  /// uid of the manager/admin who rejected the task, + when.
  String? get rejectedBy => throw _privateConstructorUsedError;
  DateTime? get rejectedAt => throw _privateConstructorUsedError;

  /// Reviewer's note left on approve/reject.
  String? get reviewNotes => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskEntityCopyWith<TaskEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskEntityCopyWith<$Res> {
  factory $TaskEntityCopyWith(
    TaskEntity value,
    $Res Function(TaskEntity) then,
  ) = _$TaskEntityCopyWithImpl<$Res, TaskEntity>;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskType type,
    TaskStatus status,
    TaskPriority priority,
    String? branchId,
    List<String> assigneeIds,
    List<ChecklistItem> checklist,
    String? createdBy,
    String? assignedShiftId,
    DateTime? deadline,
    String? notes,
    String? proofImageUrl,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? reviewNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$TaskEntityCopyWithImpl<$Res, $Val extends TaskEntity>
    implements $TaskEntityCopyWith<$Res> {
  _$TaskEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? type = null,
    Object? status = null,
    Object? priority = null,
    Object? branchId = freezed,
    Object? assigneeIds = null,
    Object? checklist = null,
    Object? createdBy = freezed,
    Object? assignedShiftId = freezed,
    Object? deadline = freezed,
    Object? notes = freezed,
    Object? proofImageUrl = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? rejectedBy = freezed,
    Object? rejectedAt = freezed,
    Object? reviewNotes = freezed,
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
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TaskStatus,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as TaskPriority,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            assigneeIds: null == assigneeIds
                ? _value.assigneeIds
                : assigneeIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            checklist: null == checklist
                ? _value.checklist
                : checklist // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistItem>,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            assignedShiftId: freezed == assignedShiftId
                ? _value.assignedShiftId
                : assignedShiftId // ignore: cast_nullable_to_non_nullable
                      as String?,
            deadline: freezed == deadline
                ? _value.deadline
                : deadline // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            proofImageUrl: freezed == proofImageUrl
                ? _value.proofImageUrl
                : proofImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            approvedBy: freezed == approvedBy
                ? _value.approvedBy
                : approvedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            approvedAt: freezed == approvedAt
                ? _value.approvedAt
                : approvedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            rejectedBy: freezed == rejectedBy
                ? _value.rejectedBy
                : rejectedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            rejectedAt: freezed == rejectedAt
                ? _value.rejectedAt
                : rejectedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reviewNotes: freezed == reviewNotes
                ? _value.reviewNotes
                : reviewNotes // ignore: cast_nullable_to_non_nullable
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
abstract class _$$TaskEntityImplCopyWith<$Res>
    implements $TaskEntityCopyWith<$Res> {
  factory _$$TaskEntityImplCopyWith(
    _$TaskEntityImpl value,
    $Res Function(_$TaskEntityImpl) then,
  ) = __$$TaskEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskType type,
    TaskStatus status,
    TaskPriority priority,
    String? branchId,
    List<String> assigneeIds,
    List<ChecklistItem> checklist,
    String? createdBy,
    String? assignedShiftId,
    DateTime? deadline,
    String? notes,
    String? proofImageUrl,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? reviewNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$TaskEntityImplCopyWithImpl<$Res>
    extends _$TaskEntityCopyWithImpl<$Res, _$TaskEntityImpl>
    implements _$$TaskEntityImplCopyWith<$Res> {
  __$$TaskEntityImplCopyWithImpl(
    _$TaskEntityImpl _value,
    $Res Function(_$TaskEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? type = null,
    Object? status = null,
    Object? priority = null,
    Object? branchId = freezed,
    Object? assigneeIds = null,
    Object? checklist = null,
    Object? createdBy = freezed,
    Object? assignedShiftId = freezed,
    Object? deadline = freezed,
    Object? notes = freezed,
    Object? proofImageUrl = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? rejectedBy = freezed,
    Object? rejectedAt = freezed,
    Object? reviewNotes = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$TaskEntityImpl(
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
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TaskStatus,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as TaskPriority,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        assigneeIds: null == assigneeIds
            ? _value._assigneeIds
            : assigneeIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        checklist: null == checklist
            ? _value._checklist
            : checklist // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistItem>,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        assignedShiftId: freezed == assignedShiftId
            ? _value.assignedShiftId
            : assignedShiftId // ignore: cast_nullable_to_non_nullable
                  as String?,
        deadline: freezed == deadline
            ? _value.deadline
            : deadline // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        proofImageUrl: freezed == proofImageUrl
            ? _value.proofImageUrl
            : proofImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        approvedBy: freezed == approvedBy
            ? _value.approvedBy
            : approvedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        approvedAt: freezed == approvedAt
            ? _value.approvedAt
            : approvedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        rejectedBy: freezed == rejectedBy
            ? _value.rejectedBy
            : rejectedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        rejectedAt: freezed == rejectedAt
            ? _value.rejectedAt
            : rejectedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewNotes: freezed == reviewNotes
            ? _value.reviewNotes
            : reviewNotes // ignore: cast_nullable_to_non_nullable
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

class _$TaskEntityImpl extends _TaskEntity {
  const _$TaskEntityImpl({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.normal,
    this.branchId,
    final List<String> assigneeIds = const <String>[],
    final List<ChecklistItem> checklist = const <ChecklistItem>[],
    this.createdBy,
    this.assignedShiftId,
    this.deadline,
    this.notes,
    this.proofImageUrl,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  }) : _assigneeIds = assigneeIds,
       _checklist = checklist,
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
  final TaskStatus status;
  @override
  @JsonKey()
  final TaskPriority priority;

  /// Owning branch (admin: any · manager: own branch).
  @override
  final String? branchId;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  final List<String> _assigneeIds;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  @override
  @JsonKey()
  List<String> get assigneeIds {
    if (_assigneeIds is EqualUnmodifiableListView) return _assigneeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assigneeIds);
  }

  /// Checklist the employee must work through (generated from a template).
  final List<ChecklistItem> _checklist;

  /// Checklist the employee must work through (generated from a template).
  @override
  @JsonKey()
  List<ChecklistItem> get checklist {
    if (_checklist is EqualUnmodifiableListView) return _checklist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklist);
  }

  /// uid of the manager/admin who created the task.
  @override
  final String? createdBy;

  /// Optional shift this task belongs to (references `shifts/{shiftId}`).
  @override
  final String? assignedShiftId;
  @override
  final DateTime? deadline;

  /// Free-text notes added by the executing employee.
  @override
  final String? notes;

  /// Download URL of the proof image the employee uploads on completion.
  @override
  final String? proofImageUrl;
  // ─── Review audit (Phase 4 — lightweight, not a full history) ───
  /// uid of the manager/admin who approved the task, + when.
  @override
  final String? approvedBy;
  @override
  final DateTime? approvedAt;

  /// uid of the manager/admin who rejected the task, + when.
  @override
  final String? rejectedBy;
  @override
  final DateTime? rejectedAt;

  /// Reviewer's note left on approve/reject.
  @override
  final String? reviewNotes;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'TaskEntity(id: $id, title: $title, description: $description, type: $type, status: $status, priority: $priority, branchId: $branchId, assigneeIds: $assigneeIds, checklist: $checklist, createdBy: $createdBy, assignedShiftId: $assignedShiftId, deadline: $deadline, notes: $notes, proofImageUrl: $proofImageUrl, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedBy: $rejectedBy, rejectedAt: $rejectedAt, reviewNotes: $reviewNotes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            const DeepCollectionEquality().equals(
              other._assigneeIds,
              _assigneeIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._checklist,
              _checklist,
            ) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.assignedShiftId, assignedShiftId) ||
                other.assignedShiftId == assignedShiftId) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.proofImageUrl, proofImageUrl) ||
                other.proofImageUrl == proofImageUrl) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.rejectedBy, rejectedBy) ||
                other.rejectedBy == rejectedBy) &&
            (identical(other.rejectedAt, rejectedAt) ||
                other.rejectedAt == rejectedAt) &&
            (identical(other.reviewNotes, reviewNotes) ||
                other.reviewNotes == reviewNotes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    description,
    type,
    status,
    priority,
    branchId,
    const DeepCollectionEquality().hash(_assigneeIds),
    const DeepCollectionEquality().hash(_checklist),
    createdBy,
    assignedShiftId,
    deadline,
    notes,
    proofImageUrl,
    approvedBy,
    approvedAt,
    rejectedBy,
    rejectedAt,
    reviewNotes,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskEntityImplCopyWith<_$TaskEntityImpl> get copyWith =>
      __$$TaskEntityImplCopyWithImpl<_$TaskEntityImpl>(this, _$identity);
}

abstract class _TaskEntity extends TaskEntity {
  const factory _TaskEntity({
    required final String id,
    required final String title,
    final String? description,
    final TaskType type,
    final TaskStatus status,
    final TaskPriority priority,
    final String? branchId,
    final List<String> assigneeIds,
    final List<ChecklistItem> checklist,
    final String? createdBy,
    final String? assignedShiftId,
    final DateTime? deadline,
    final String? notes,
    final String? proofImageUrl,
    final String? approvedBy,
    final DateTime? approvedAt,
    final String? rejectedBy,
    final DateTime? rejectedAt,
    final String? reviewNotes,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$TaskEntityImpl;
  const _TaskEntity._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;
  @override
  TaskType get type;
  @override
  TaskStatus get status;
  @override
  TaskPriority get priority;

  /// Owning branch (admin: any · manager: own branch).
  @override
  String? get branchId;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  @override
  List<String> get assigneeIds;

  /// Checklist the employee must work through (generated from a template).
  @override
  List<ChecklistItem> get checklist;

  /// uid of the manager/admin who created the task.
  @override
  String? get createdBy;

  /// Optional shift this task belongs to (references `shifts/{shiftId}`).
  @override
  String? get assignedShiftId;
  @override
  DateTime? get deadline;

  /// Free-text notes added by the executing employee.
  @override
  String? get notes;

  /// Download URL of the proof image the employee uploads on completion.
  @override
  String? get proofImageUrl; // ─── Review audit (Phase 4 — lightweight, not a full history) ───
  /// uid of the manager/admin who approved the task, + when.
  @override
  String? get approvedBy;
  @override
  DateTime? get approvedAt;

  /// uid of the manager/admin who rejected the task, + when.
  @override
  String? get rejectedBy;
  @override
  DateTime? get rejectedAt;

  /// Reviewer's note left on approve/reject.
  @override
  String? get reviewNotes;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskEntityImplCopyWith<_$TaskEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
