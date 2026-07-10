// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weekly_schedule_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$WeeklyScheduleEntity {
  String get id => throw _privateConstructorUsedError;
  String get branchId => throw _privateConstructorUsedError;

  /// The Sunday (00:00) that starts this week.
  DateTime get weekStart => throw _privateConstructorUsedError;

  /// Roster: `day → shift → list of employee uids`.
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> get assignments =>
      throw _privateConstructorUsedError;

  /// Manager note pinned to a day (Inventory · Big delivery · …); at most
  /// one short note per day — days without a note simply have no entry.
  Map<ScheduleDay, String> get dayNotes => throw _privateConstructorUsedError;

  /// Day-level absences: `day → uid → leave type`. Leave is per **day**, not
  /// per shift — a person on leave is away for the whole day.
  Map<ScheduleDay, Map<String, LeaveType>> get leave =>
      throw _privateConstructorUsedError;

  /// Per-week **shift-hours overrides**: `day → shift → hours`. Only slots
  /// that differ from [ShiftHours.standard] are stored — an empty map means
  /// the whole week runs standard hours. This is where configurable end times
  /// live (weekend lateness, Ramadan, holidays…): read through [hoursFor],
  /// never from a hardcoded weekend rule.
  Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> get shiftHours =>
      throw _privateConstructorUsedError;

  /// The week's **frozen shift-hours snapshot** (Schedule V2 · Pillar 5),
  /// captured from the branch's shift templates when the week was created.
  /// Resolves *between* the per-slot [shiftHours] override and the hardcoded
  /// [ShiftHours.standard] fallback — see [hoursFor]. **Null on every legacy
  /// week**, which therefore resolves exactly as before (standard hours).
  ShiftPlan? get shiftPlan => throw _privateConstructorUsedError;

  /// uid of the manager/admin who created the schedule.
  String? get createdBy => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of WeeklyScheduleEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WeeklyScheduleEntityCopyWith<WeeklyScheduleEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WeeklyScheduleEntityCopyWith<$Res> {
  factory $WeeklyScheduleEntityCopyWith(
    WeeklyScheduleEntity value,
    $Res Function(WeeklyScheduleEntity) then,
  ) = _$WeeklyScheduleEntityCopyWithImpl<$Res, WeeklyScheduleEntity>;
  @useResult
  $Res call({
    String id,
    String branchId,
    DateTime weekStart,
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,
    Map<ScheduleDay, String> dayNotes,
    Map<ScheduleDay, Map<String, LeaveType>> leave,
    Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours,
    ShiftPlan? shiftPlan,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$WeeklyScheduleEntityCopyWithImpl<
  $Res,
  $Val extends WeeklyScheduleEntity
>
    implements $WeeklyScheduleEntityCopyWith<$Res> {
  _$WeeklyScheduleEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WeeklyScheduleEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? branchId = null,
    Object? weekStart = null,
    Object? assignments = null,
    Object? dayNotes = null,
    Object? leave = null,
    Object? shiftHours = null,
    Object? shiftPlan = freezed,
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
            branchId: null == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String,
            weekStart: null == weekStart
                ? _value.weekStart
                : weekStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            assignments: null == assignments
                ? _value.assignments
                : assignments // ignore: cast_nullable_to_non_nullable
                      as Map<ScheduleDay, Map<ScheduleShift, List<String>>>,
            dayNotes: null == dayNotes
                ? _value.dayNotes
                : dayNotes // ignore: cast_nullable_to_non_nullable
                      as Map<ScheduleDay, String>,
            leave: null == leave
                ? _value.leave
                : leave // ignore: cast_nullable_to_non_nullable
                      as Map<ScheduleDay, Map<String, LeaveType>>,
            shiftHours: null == shiftHours
                ? _value.shiftHours
                : shiftHours // ignore: cast_nullable_to_non_nullable
                      as Map<ScheduleDay, Map<ScheduleShift, ShiftHours>>,
            shiftPlan: freezed == shiftPlan
                ? _value.shiftPlan
                : shiftPlan // ignore: cast_nullable_to_non_nullable
                      as ShiftPlan?,
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
abstract class _$$WeeklyScheduleEntityImplCopyWith<$Res>
    implements $WeeklyScheduleEntityCopyWith<$Res> {
  factory _$$WeeklyScheduleEntityImplCopyWith(
    _$WeeklyScheduleEntityImpl value,
    $Res Function(_$WeeklyScheduleEntityImpl) then,
  ) = __$$WeeklyScheduleEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String branchId,
    DateTime weekStart,
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,
    Map<ScheduleDay, String> dayNotes,
    Map<ScheduleDay, Map<String, LeaveType>> leave,
    Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours,
    ShiftPlan? shiftPlan,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$WeeklyScheduleEntityImplCopyWithImpl<$Res>
    extends _$WeeklyScheduleEntityCopyWithImpl<$Res, _$WeeklyScheduleEntityImpl>
    implements _$$WeeklyScheduleEntityImplCopyWith<$Res> {
  __$$WeeklyScheduleEntityImplCopyWithImpl(
    _$WeeklyScheduleEntityImpl _value,
    $Res Function(_$WeeklyScheduleEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WeeklyScheduleEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? branchId = null,
    Object? weekStart = null,
    Object? assignments = null,
    Object? dayNotes = null,
    Object? leave = null,
    Object? shiftHours = null,
    Object? shiftPlan = freezed,
    Object? createdBy = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$WeeklyScheduleEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        branchId: null == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String,
        weekStart: null == weekStart
            ? _value.weekStart
            : weekStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        assignments: null == assignments
            ? _value._assignments
            : assignments // ignore: cast_nullable_to_non_nullable
                  as Map<ScheduleDay, Map<ScheduleShift, List<String>>>,
        dayNotes: null == dayNotes
            ? _value._dayNotes
            : dayNotes // ignore: cast_nullable_to_non_nullable
                  as Map<ScheduleDay, String>,
        leave: null == leave
            ? _value._leave
            : leave // ignore: cast_nullable_to_non_nullable
                  as Map<ScheduleDay, Map<String, LeaveType>>,
        shiftHours: null == shiftHours
            ? _value._shiftHours
            : shiftHours // ignore: cast_nullable_to_non_nullable
                  as Map<ScheduleDay, Map<ScheduleShift, ShiftHours>>,
        shiftPlan: freezed == shiftPlan
            ? _value.shiftPlan
            : shiftPlan // ignore: cast_nullable_to_non_nullable
                  as ShiftPlan?,
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

class _$WeeklyScheduleEntityImpl extends _WeeklyScheduleEntity {
  const _$WeeklyScheduleEntityImpl({
    required this.id,
    required this.branchId,
    required this.weekStart,
    final Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments =
        const <ScheduleDay, Map<ScheduleShift, List<String>>>{},
    final Map<ScheduleDay, String> dayNotes = const <ScheduleDay, String>{},
    final Map<ScheduleDay, Map<String, LeaveType>> leave =
        const <ScheduleDay, Map<String, LeaveType>>{},
    final Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours =
        const <ScheduleDay, Map<ScheduleShift, ShiftHours>>{},
    this.shiftPlan,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  }) : _assignments = assignments,
       _dayNotes = dayNotes,
       _leave = leave,
       _shiftHours = shiftHours,
       super._();

  @override
  final String id;
  @override
  final String branchId;

  /// The Sunday (00:00) that starts this week.
  @override
  final DateTime weekStart;

  /// Roster: `day → shift → list of employee uids`.
  final Map<ScheduleDay, Map<ScheduleShift, List<String>>> _assignments;

  /// Roster: `day → shift → list of employee uids`.
  @override
  @JsonKey()
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> get assignments {
    if (_assignments is EqualUnmodifiableMapView) return _assignments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_assignments);
  }

  /// Manager note pinned to a day (Inventory · Big delivery · …); at most
  /// one short note per day — days without a note simply have no entry.
  final Map<ScheduleDay, String> _dayNotes;

  /// Manager note pinned to a day (Inventory · Big delivery · …); at most
  /// one short note per day — days without a note simply have no entry.
  @override
  @JsonKey()
  Map<ScheduleDay, String> get dayNotes {
    if (_dayNotes is EqualUnmodifiableMapView) return _dayNotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dayNotes);
  }

  /// Day-level absences: `day → uid → leave type`. Leave is per **day**, not
  /// per shift — a person on leave is away for the whole day.
  final Map<ScheduleDay, Map<String, LeaveType>> _leave;

  /// Day-level absences: `day → uid → leave type`. Leave is per **day**, not
  /// per shift — a person on leave is away for the whole day.
  @override
  @JsonKey()
  Map<ScheduleDay, Map<String, LeaveType>> get leave {
    if (_leave is EqualUnmodifiableMapView) return _leave;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_leave);
  }

  /// Per-week **shift-hours overrides**: `day → shift → hours`. Only slots
  /// that differ from [ShiftHours.standard] are stored — an empty map means
  /// the whole week runs standard hours. This is where configurable end times
  /// live (weekend lateness, Ramadan, holidays…): read through [hoursFor],
  /// never from a hardcoded weekend rule.
  final Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> _shiftHours;

  /// Per-week **shift-hours overrides**: `day → shift → hours`. Only slots
  /// that differ from [ShiftHours.standard] are stored — an empty map means
  /// the whole week runs standard hours. This is where configurable end times
  /// live (weekend lateness, Ramadan, holidays…): read through [hoursFor],
  /// never from a hardcoded weekend rule.
  @override
  @JsonKey()
  Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> get shiftHours {
    if (_shiftHours is EqualUnmodifiableMapView) return _shiftHours;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_shiftHours);
  }

  /// The week's **frozen shift-hours snapshot** (Schedule V2 · Pillar 5),
  /// captured from the branch's shift templates when the week was created.
  /// Resolves *between* the per-slot [shiftHours] override and the hardcoded
  /// [ShiftHours.standard] fallback — see [hoursFor]. **Null on every legacy
  /// week**, which therefore resolves exactly as before (standard hours).
  @override
  final ShiftPlan? shiftPlan;

  /// uid of the manager/admin who created the schedule.
  @override
  final String? createdBy;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'WeeklyScheduleEntity(id: $id, branchId: $branchId, weekStart: $weekStart, assignments: $assignments, dayNotes: $dayNotes, leave: $leave, shiftHours: $shiftHours, shiftPlan: $shiftPlan, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyScheduleEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.weekStart, weekStart) ||
                other.weekStart == weekStart) &&
            const DeepCollectionEquality().equals(
              other._assignments,
              _assignments,
            ) &&
            const DeepCollectionEquality().equals(other._dayNotes, _dayNotes) &&
            const DeepCollectionEquality().equals(other._leave, _leave) &&
            const DeepCollectionEquality().equals(
              other._shiftHours,
              _shiftHours,
            ) &&
            (identical(other.shiftPlan, shiftPlan) ||
                other.shiftPlan == shiftPlan) &&
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
    branchId,
    weekStart,
    const DeepCollectionEquality().hash(_assignments),
    const DeepCollectionEquality().hash(_dayNotes),
    const DeepCollectionEquality().hash(_leave),
    const DeepCollectionEquality().hash(_shiftHours),
    shiftPlan,
    createdBy,
    createdAt,
    updatedAt,
  );

  /// Create a copy of WeeklyScheduleEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyScheduleEntityImplCopyWith<_$WeeklyScheduleEntityImpl>
  get copyWith =>
      __$$WeeklyScheduleEntityImplCopyWithImpl<_$WeeklyScheduleEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _WeeklyScheduleEntity extends WeeklyScheduleEntity {
  const factory _WeeklyScheduleEntity({
    required final String id,
    required final String branchId,
    required final DateTime weekStart,
    final Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,
    final Map<ScheduleDay, String> dayNotes,
    final Map<ScheduleDay, Map<String, LeaveType>> leave,
    final Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours,
    final ShiftPlan? shiftPlan,
    final String? createdBy,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$WeeklyScheduleEntityImpl;
  const _WeeklyScheduleEntity._() : super._();

  @override
  String get id;
  @override
  String get branchId;

  /// The Sunday (00:00) that starts this week.
  @override
  DateTime get weekStart;

  /// Roster: `day → shift → list of employee uids`.
  @override
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> get assignments;

  /// Manager note pinned to a day (Inventory · Big delivery · …); at most
  /// one short note per day — days without a note simply have no entry.
  @override
  Map<ScheduleDay, String> get dayNotes;

  /// Day-level absences: `day → uid → leave type`. Leave is per **day**, not
  /// per shift — a person on leave is away for the whole day.
  @override
  Map<ScheduleDay, Map<String, LeaveType>> get leave;

  /// Per-week **shift-hours overrides**: `day → shift → hours`. Only slots
  /// that differ from [ShiftHours.standard] are stored — an empty map means
  /// the whole week runs standard hours. This is where configurable end times
  /// live (weekend lateness, Ramadan, holidays…): read through [hoursFor],
  /// never from a hardcoded weekend rule.
  @override
  Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> get shiftHours;

  /// The week's **frozen shift-hours snapshot** (Schedule V2 · Pillar 5),
  /// captured from the branch's shift templates when the week was created.
  /// Resolves *between* the per-slot [shiftHours] override and the hardcoded
  /// [ShiftHours.standard] fallback — see [hoursFor]. **Null on every legacy
  /// week**, which therefore resolves exactly as before (standard hours).
  @override
  ShiftPlan? get shiftPlan;

  /// uid of the manager/admin who created the schedule.
  @override
  String? get createdBy;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of WeeklyScheduleEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WeeklyScheduleEntityImplCopyWith<_$WeeklyScheduleEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}
