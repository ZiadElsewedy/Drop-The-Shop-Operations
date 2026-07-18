// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurring_task_template_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RecurringTaskTemplateEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  TaskPriority get priority => throw _privateConstructorUsedError;
  List<ChecklistItemTemplate> get checklistItems =>
      throw _privateConstructorUsedError;
  String get branchId => throw _privateConstructorUsedError;
  ScheduleShift get shift => throw _privateConstructorUsedError;
  TemplateRepeatMode get repeat => throw _privateConstructorUsedError;

  /// Target weekday when [repeat] is [TemplateRepeatMode.weekly]:
  /// `DateTime.monday` = 1 … `DateTime.sunday` = 7 (matches [RecurrenceConfig.weekday]).
  int get weekday => throw _privateConstructorUsedError;

  /// Whether the generator should still produce instances from this template.
  /// A manager pausing/retiring a routine sets this false rather than
  /// deleting the template — past instances (and their analytics) are
  /// untouched either way.
  bool get active => throw _privateConstructorUsedError;
  String? get createdBy => throw _privateConstructorUsedError;

  /// uid of whoever last edited this routine (client-written on update).
  String? get updatedBy => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt =>
      throw _privateConstructorUsedError; // ─── Automation health (Automation Center) ──────────────────────────
  // Cloud-Function-owned rollups, written by `generateShiftTaskInstances` via
  // the Admin SDK and **read-only** to the client (never in `toMap`, like a
  // task's `version`). They let the Automation Center show a routine's health
  // without reading Cloud Logging — see docs/design/AUTOMATION_ENGINE.md.
  /// Last time the generator attempted this routine.
  DateTime? get lastRunAt => throw _privateConstructorUsedError;

  /// Next scheduled generation (computed by the function; advisory).
  DateTime? get nextRunAt => throw _privateConstructorUsedError;

  /// Outcome of the last run: `completed` / `skipped` / `failed`
  /// (null = never run).
  String? get lastStatus => throw _privateConstructorUsedError;

  /// The task id the last successful run generated.
  String? get lastGeneratedTaskId => throw _privateConstructorUsedError;

  /// Consecutive generation failures; reset to 0 on a successful run.
  int get failureCount =>
      throw _privateConstructorUsedError; // ─── Cumulative health counters (Automation observability, ADR-011) ──
  // Monotonic totals the Cloud Function increments per run (O(1) writes) so the
  // whole health panel is ONE read; derived rate/avg live in [AutomationHealth]
  // and are never stored. All CF-owned and **read-only** to the client (never
  // in `toMap`, like the rollups above).
  /// A monotonic version of the definition, bumped by the lifecycle CF on any
  /// config change; captured onto each run so history is attributable.
  int get configVersion => throw _privateConstructorUsedError;

  /// Total generation runs recorded (completed + skipped + failed).
  int get runCount => throw _privateConstructorUsedError;

  /// Runs that completed (a task was generated).
  int get successCount => throw _privateConstructorUsedError;

  /// Runs that failed.
  int get failedCount => throw _privateConstructorUsedError;

  /// Runs that were skipped (the day's task already existed).
  int get skippedCount => throw _privateConstructorUsedError;

  /// Sum of run durations in ms; averaged on read (never stored averaged).
  int get totalDurationMs => throw _privateConstructorUsedError;

  /// Last successful generation.
  DateTime? get lastSuccessAt => throw _privateConstructorUsedError;

  /// Last failed generation.
  DateTime? get lastFailureAt => throw _privateConstructorUsedError;

  /// Create a copy of RecurringTaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecurringTaskTemplateEntityCopyWith<RecurringTaskTemplateEntity>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurringTaskTemplateEntityCopyWith<$Res> {
  factory $RecurringTaskTemplateEntityCopyWith(
    RecurringTaskTemplateEntity value,
    $Res Function(RecurringTaskTemplateEntity) then,
  ) =
      _$RecurringTaskTemplateEntityCopyWithImpl<
        $Res,
        RecurringTaskTemplateEntity
      >;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskPriority priority,
    List<ChecklistItemTemplate> checklistItems,
    String branchId,
    ScheduleShift shift,
    TemplateRepeatMode repeat,
    int weekday,
    bool active,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    String? lastStatus,
    String? lastGeneratedTaskId,
    int failureCount,
    int configVersion,
    int runCount,
    int successCount,
    int failedCount,
    int skippedCount,
    int totalDurationMs,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
  });
}

/// @nodoc
class _$RecurringTaskTemplateEntityCopyWithImpl<
  $Res,
  $Val extends RecurringTaskTemplateEntity
>
    implements $RecurringTaskTemplateEntityCopyWith<$Res> {
  _$RecurringTaskTemplateEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecurringTaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? priority = null,
    Object? checklistItems = null,
    Object? branchId = null,
    Object? shift = null,
    Object? repeat = null,
    Object? weekday = null,
    Object? active = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? lastRunAt = freezed,
    Object? nextRunAt = freezed,
    Object? lastStatus = freezed,
    Object? lastGeneratedTaskId = freezed,
    Object? failureCount = null,
    Object? configVersion = null,
    Object? runCount = null,
    Object? successCount = null,
    Object? failedCount = null,
    Object? skippedCount = null,
    Object? totalDurationMs = null,
    Object? lastSuccessAt = freezed,
    Object? lastFailureAt = freezed,
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
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as TaskPriority,
            checklistItems: null == checklistItems
                ? _value.checklistItems
                : checklistItems // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistItemTemplate>,
            branchId: null == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String,
            shift: null == shift
                ? _value.shift
                : shift // ignore: cast_nullable_to_non_nullable
                      as ScheduleShift,
            repeat: null == repeat
                ? _value.repeat
                : repeat // ignore: cast_nullable_to_non_nullable
                      as TemplateRepeatMode,
            weekday: null == weekday
                ? _value.weekday
                : weekday // ignore: cast_nullable_to_non_nullable
                      as int,
            active: null == active
                ? _value.active
                : active // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            updatedBy: freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastRunAt: freezed == lastRunAt
                ? _value.lastRunAt
                : lastRunAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            nextRunAt: freezed == nextRunAt
                ? _value.nextRunAt
                : nextRunAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastStatus: freezed == lastStatus
                ? _value.lastStatus
                : lastStatus // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastGeneratedTaskId: freezed == lastGeneratedTaskId
                ? _value.lastGeneratedTaskId
                : lastGeneratedTaskId // ignore: cast_nullable_to_non_nullable
                      as String?,
            failureCount: null == failureCount
                ? _value.failureCount
                : failureCount // ignore: cast_nullable_to_non_nullable
                      as int,
            configVersion: null == configVersion
                ? _value.configVersion
                : configVersion // ignore: cast_nullable_to_non_nullable
                      as int,
            runCount: null == runCount
                ? _value.runCount
                : runCount // ignore: cast_nullable_to_non_nullable
                      as int,
            successCount: null == successCount
                ? _value.successCount
                : successCount // ignore: cast_nullable_to_non_nullable
                      as int,
            failedCount: null == failedCount
                ? _value.failedCount
                : failedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            skippedCount: null == skippedCount
                ? _value.skippedCount
                : skippedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            totalDurationMs: null == totalDurationMs
                ? _value.totalDurationMs
                : totalDurationMs // ignore: cast_nullable_to_non_nullable
                      as int,
            lastSuccessAt: freezed == lastSuccessAt
                ? _value.lastSuccessAt
                : lastSuccessAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastFailureAt: freezed == lastFailureAt
                ? _value.lastFailureAt
                : lastFailureAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecurringTaskTemplateEntityImplCopyWith<$Res>
    implements $RecurringTaskTemplateEntityCopyWith<$Res> {
  factory _$$RecurringTaskTemplateEntityImplCopyWith(
    _$RecurringTaskTemplateEntityImpl value,
    $Res Function(_$RecurringTaskTemplateEntityImpl) then,
  ) = __$$RecurringTaskTemplateEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskPriority priority,
    List<ChecklistItemTemplate> checklistItems,
    String branchId,
    ScheduleShift shift,
    TemplateRepeatMode repeat,
    int weekday,
    bool active,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    String? lastStatus,
    String? lastGeneratedTaskId,
    int failureCount,
    int configVersion,
    int runCount,
    int successCount,
    int failedCount,
    int skippedCount,
    int totalDurationMs,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
  });
}

/// @nodoc
class __$$RecurringTaskTemplateEntityImplCopyWithImpl<$Res>
    extends
        _$RecurringTaskTemplateEntityCopyWithImpl<
          $Res,
          _$RecurringTaskTemplateEntityImpl
        >
    implements _$$RecurringTaskTemplateEntityImplCopyWith<$Res> {
  __$$RecurringTaskTemplateEntityImplCopyWithImpl(
    _$RecurringTaskTemplateEntityImpl _value,
    $Res Function(_$RecurringTaskTemplateEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecurringTaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? priority = null,
    Object? checklistItems = null,
    Object? branchId = null,
    Object? shift = null,
    Object? repeat = null,
    Object? weekday = null,
    Object? active = null,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? lastRunAt = freezed,
    Object? nextRunAt = freezed,
    Object? lastStatus = freezed,
    Object? lastGeneratedTaskId = freezed,
    Object? failureCount = null,
    Object? configVersion = null,
    Object? runCount = null,
    Object? successCount = null,
    Object? failedCount = null,
    Object? skippedCount = null,
    Object? totalDurationMs = null,
    Object? lastSuccessAt = freezed,
    Object? lastFailureAt = freezed,
  }) {
    return _then(
      _$RecurringTaskTemplateEntityImpl(
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
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as TaskPriority,
        checklistItems: null == checklistItems
            ? _value._checklistItems
            : checklistItems // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistItemTemplate>,
        branchId: null == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String,
        shift: null == shift
            ? _value.shift
            : shift // ignore: cast_nullable_to_non_nullable
                  as ScheduleShift,
        repeat: null == repeat
            ? _value.repeat
            : repeat // ignore: cast_nullable_to_non_nullable
                  as TemplateRepeatMode,
        weekday: null == weekday
            ? _value.weekday
            : weekday // ignore: cast_nullable_to_non_nullable
                  as int,
        active: null == active
            ? _value.active
            : active // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        updatedBy: freezed == updatedBy
            ? _value.updatedBy
            : updatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastRunAt: freezed == lastRunAt
            ? _value.lastRunAt
            : lastRunAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        nextRunAt: freezed == nextRunAt
            ? _value.nextRunAt
            : nextRunAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastStatus: freezed == lastStatus
            ? _value.lastStatus
            : lastStatus // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastGeneratedTaskId: freezed == lastGeneratedTaskId
            ? _value.lastGeneratedTaskId
            : lastGeneratedTaskId // ignore: cast_nullable_to_non_nullable
                  as String?,
        failureCount: null == failureCount
            ? _value.failureCount
            : failureCount // ignore: cast_nullable_to_non_nullable
                  as int,
        configVersion: null == configVersion
            ? _value.configVersion
            : configVersion // ignore: cast_nullable_to_non_nullable
                  as int,
        runCount: null == runCount
            ? _value.runCount
            : runCount // ignore: cast_nullable_to_non_nullable
                  as int,
        successCount: null == successCount
            ? _value.successCount
            : successCount // ignore: cast_nullable_to_non_nullable
                  as int,
        failedCount: null == failedCount
            ? _value.failedCount
            : failedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        skippedCount: null == skippedCount
            ? _value.skippedCount
            : skippedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalDurationMs: null == totalDurationMs
            ? _value.totalDurationMs
            : totalDurationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        lastSuccessAt: freezed == lastSuccessAt
            ? _value.lastSuccessAt
            : lastSuccessAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastFailureAt: freezed == lastFailureAt
            ? _value.lastFailureAt
            : lastFailureAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$RecurringTaskTemplateEntityImpl extends _RecurringTaskTemplateEntity {
  const _$RecurringTaskTemplateEntityImpl({
    required this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.normal,
    final List<ChecklistItemTemplate> checklistItems =
        const <ChecklistItemTemplate>[],
    required this.branchId,
    required this.shift,
    this.repeat = TemplateRepeatMode.daily,
    this.weekday = 1,
    this.active = true,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.lastRunAt,
    this.nextRunAt,
    this.lastStatus,
    this.lastGeneratedTaskId,
    this.failureCount = 0,
    this.configVersion = 1,
    this.runCount = 0,
    this.successCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.totalDurationMs = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
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
  final TaskPriority priority;
  final List<ChecklistItemTemplate> _checklistItems;
  @override
  @JsonKey()
  List<ChecklistItemTemplate> get checklistItems {
    if (_checklistItems is EqualUnmodifiableListView) return _checklistItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklistItems);
  }

  @override
  final String branchId;
  @override
  final ScheduleShift shift;
  @override
  @JsonKey()
  final TemplateRepeatMode repeat;

  /// Target weekday when [repeat] is [TemplateRepeatMode.weekly]:
  /// `DateTime.monday` = 1 … `DateTime.sunday` = 7 (matches [RecurrenceConfig.weekday]).
  @override
  @JsonKey()
  final int weekday;

  /// Whether the generator should still produce instances from this template.
  /// A manager pausing/retiring a routine sets this false rather than
  /// deleting the template — past instances (and their analytics) are
  /// untouched either way.
  @override
  @JsonKey()
  final bool active;
  @override
  final String? createdBy;

  /// uid of whoever last edited this routine (client-written on update).
  @override
  final String? updatedBy;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  // ─── Automation health (Automation Center) ──────────────────────────
  // Cloud-Function-owned rollups, written by `generateShiftTaskInstances` via
  // the Admin SDK and **read-only** to the client (never in `toMap`, like a
  // task's `version`). They let the Automation Center show a routine's health
  // without reading Cloud Logging — see docs/design/AUTOMATION_ENGINE.md.
  /// Last time the generator attempted this routine.
  @override
  final DateTime? lastRunAt;

  /// Next scheduled generation (computed by the function; advisory).
  @override
  final DateTime? nextRunAt;

  /// Outcome of the last run: `completed` / `skipped` / `failed`
  /// (null = never run).
  @override
  final String? lastStatus;

  /// The task id the last successful run generated.
  @override
  final String? lastGeneratedTaskId;

  /// Consecutive generation failures; reset to 0 on a successful run.
  @override
  @JsonKey()
  final int failureCount;
  // ─── Cumulative health counters (Automation observability, ADR-011) ──
  // Monotonic totals the Cloud Function increments per run (O(1) writes) so the
  // whole health panel is ONE read; derived rate/avg live in [AutomationHealth]
  // and are never stored. All CF-owned and **read-only** to the client (never
  // in `toMap`, like the rollups above).
  /// A monotonic version of the definition, bumped by the lifecycle CF on any
  /// config change; captured onto each run so history is attributable.
  @override
  @JsonKey()
  final int configVersion;

  /// Total generation runs recorded (completed + skipped + failed).
  @override
  @JsonKey()
  final int runCount;

  /// Runs that completed (a task was generated).
  @override
  @JsonKey()
  final int successCount;

  /// Runs that failed.
  @override
  @JsonKey()
  final int failedCount;

  /// Runs that were skipped (the day's task already existed).
  @override
  @JsonKey()
  final int skippedCount;

  /// Sum of run durations in ms; averaged on read (never stored averaged).
  @override
  @JsonKey()
  final int totalDurationMs;

  /// Last successful generation.
  @override
  final DateTime? lastSuccessAt;

  /// Last failed generation.
  @override
  final DateTime? lastFailureAt;

  @override
  String toString() {
    return 'RecurringTaskTemplateEntity(id: $id, title: $title, description: $description, priority: $priority, checklistItems: $checklistItems, branchId: $branchId, shift: $shift, repeat: $repeat, weekday: $weekday, active: $active, createdBy: $createdBy, updatedBy: $updatedBy, createdAt: $createdAt, updatedAt: $updatedAt, lastRunAt: $lastRunAt, nextRunAt: $nextRunAt, lastStatus: $lastStatus, lastGeneratedTaskId: $lastGeneratedTaskId, failureCount: $failureCount, configVersion: $configVersion, runCount: $runCount, successCount: $successCount, failedCount: $failedCount, skippedCount: $skippedCount, totalDurationMs: $totalDurationMs, lastSuccessAt: $lastSuccessAt, lastFailureAt: $lastFailureAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurringTaskTemplateEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            const DeepCollectionEquality().equals(
              other._checklistItems,
              _checklistItems,
            ) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.repeat, repeat) || other.repeat == repeat) &&
            (identical(other.weekday, weekday) || other.weekday == weekday) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastRunAt, lastRunAt) ||
                other.lastRunAt == lastRunAt) &&
            (identical(other.nextRunAt, nextRunAt) ||
                other.nextRunAt == nextRunAt) &&
            (identical(other.lastStatus, lastStatus) ||
                other.lastStatus == lastStatus) &&
            (identical(other.lastGeneratedTaskId, lastGeneratedTaskId) ||
                other.lastGeneratedTaskId == lastGeneratedTaskId) &&
            (identical(other.failureCount, failureCount) ||
                other.failureCount == failureCount) &&
            (identical(other.configVersion, configVersion) ||
                other.configVersion == configVersion) &&
            (identical(other.runCount, runCount) ||
                other.runCount == runCount) &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.failedCount, failedCount) ||
                other.failedCount == failedCount) &&
            (identical(other.skippedCount, skippedCount) ||
                other.skippedCount == skippedCount) &&
            (identical(other.totalDurationMs, totalDurationMs) ||
                other.totalDurationMs == totalDurationMs) &&
            (identical(other.lastSuccessAt, lastSuccessAt) ||
                other.lastSuccessAt == lastSuccessAt) &&
            (identical(other.lastFailureAt, lastFailureAt) ||
                other.lastFailureAt == lastFailureAt));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    description,
    priority,
    const DeepCollectionEquality().hash(_checklistItems),
    branchId,
    shift,
    repeat,
    weekday,
    active,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    lastRunAt,
    nextRunAt,
    lastStatus,
    lastGeneratedTaskId,
    failureCount,
    configVersion,
    runCount,
    successCount,
    failedCount,
    skippedCount,
    totalDurationMs,
    lastSuccessAt,
    lastFailureAt,
  ]);

  /// Create a copy of RecurringTaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurringTaskTemplateEntityImplCopyWith<_$RecurringTaskTemplateEntityImpl>
  get copyWith =>
      __$$RecurringTaskTemplateEntityImplCopyWithImpl<
        _$RecurringTaskTemplateEntityImpl
      >(this, _$identity);
}

abstract class _RecurringTaskTemplateEntity
    extends RecurringTaskTemplateEntity {
  const factory _RecurringTaskTemplateEntity({
    required final String id,
    required final String title,
    final String? description,
    final TaskPriority priority,
    final List<ChecklistItemTemplate> checklistItems,
    required final String branchId,
    required final ScheduleShift shift,
    final TemplateRepeatMode repeat,
    final int weekday,
    final bool active,
    final String? createdBy,
    final String? updatedBy,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? lastRunAt,
    final DateTime? nextRunAt,
    final String? lastStatus,
    final String? lastGeneratedTaskId,
    final int failureCount,
    final int configVersion,
    final int runCount,
    final int successCount,
    final int failedCount,
    final int skippedCount,
    final int totalDurationMs,
    final DateTime? lastSuccessAt,
    final DateTime? lastFailureAt,
  }) = _$RecurringTaskTemplateEntityImpl;
  const _RecurringTaskTemplateEntity._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;
  @override
  TaskPriority get priority;
  @override
  List<ChecklistItemTemplate> get checklistItems;
  @override
  String get branchId;
  @override
  ScheduleShift get shift;
  @override
  TemplateRepeatMode get repeat;

  /// Target weekday when [repeat] is [TemplateRepeatMode.weekly]:
  /// `DateTime.monday` = 1 … `DateTime.sunday` = 7 (matches [RecurrenceConfig.weekday]).
  @override
  int get weekday;

  /// Whether the generator should still produce instances from this template.
  /// A manager pausing/retiring a routine sets this false rather than
  /// deleting the template — past instances (and their analytics) are
  /// untouched either way.
  @override
  bool get active;
  @override
  String? get createdBy;

  /// uid of whoever last edited this routine (client-written on update).
  @override
  String? get updatedBy;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt; // ─── Automation health (Automation Center) ──────────────────────────
  // Cloud-Function-owned rollups, written by `generateShiftTaskInstances` via
  // the Admin SDK and **read-only** to the client (never in `toMap`, like a
  // task's `version`). They let the Automation Center show a routine's health
  // without reading Cloud Logging — see docs/design/AUTOMATION_ENGINE.md.
  /// Last time the generator attempted this routine.
  @override
  DateTime? get lastRunAt;

  /// Next scheduled generation (computed by the function; advisory).
  @override
  DateTime? get nextRunAt;

  /// Outcome of the last run: `completed` / `skipped` / `failed`
  /// (null = never run).
  @override
  String? get lastStatus;

  /// The task id the last successful run generated.
  @override
  String? get lastGeneratedTaskId;

  /// Consecutive generation failures; reset to 0 on a successful run.
  @override
  int get failureCount; // ─── Cumulative health counters (Automation observability, ADR-011) ──
  // Monotonic totals the Cloud Function increments per run (O(1) writes) so the
  // whole health panel is ONE read; derived rate/avg live in [AutomationHealth]
  // and are never stored. All CF-owned and **read-only** to the client (never
  // in `toMap`, like the rollups above).
  /// A monotonic version of the definition, bumped by the lifecycle CF on any
  /// config change; captured onto each run so history is attributable.
  @override
  int get configVersion;

  /// Total generation runs recorded (completed + skipped + failed).
  @override
  int get runCount;

  /// Runs that completed (a task was generated).
  @override
  int get successCount;

  /// Runs that failed.
  @override
  int get failedCount;

  /// Runs that were skipped (the day's task already existed).
  @override
  int get skippedCount;

  /// Sum of run durations in ms; averaged on read (never stored averaged).
  @override
  int get totalDurationMs;

  /// Last successful generation.
  @override
  DateTime? get lastSuccessAt;

  /// Last failed generation.
  @override
  DateTime? get lastFailureAt;

  /// Create a copy of RecurringTaskTemplateEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecurringTaskTemplateEntityImplCopyWith<_$RecurringTaskTemplateEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}
