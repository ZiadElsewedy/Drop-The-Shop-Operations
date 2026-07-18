// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_correction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AttendanceCorrectionEntity {
  String get id => throw _privateConstructorUsedError;

  /// The parent record's deterministic id (`{uid}_{yyyyMMdd}_{shift}`).
  String get attendanceId => throw _privateConstructorUsedError;

  /// Whose attendance this is (== [requestedBy] — the filer is the record's
  /// own employee; enforced by the create rule).
  String get userId => throw _privateConstructorUsedError;
  String? get userName => throw _privateConstructorUsedError;
  String? get branchId => throw _privateConstructorUsedError;

  /// Denormalized for the reviewer's queue row (avoids a record fetch per row).
  ScheduleShift? get shift => throw _privateConstructorUsedError;
  DateTime? get date => throw _privateConstructorUsedError;
  String get requestedBy => throw _privateConstructorUsedError;
  String? get requestedByName => throw _privateConstructorUsedError;
  AttendanceCorrectionKind get kind => throw _privateConstructorUsedError;
  RequestStatus get status => throw _privateConstructorUsedError;

  /// Why the record is wrong (the employee's explanation) — always required.
  String get reason => throw _privateConstructorUsedError;

  /// The scheduled window this correction is measured against. On a correction
  /// to an **existing** record these are redundant (the record already has
  /// them). On a **missed-punch** materialization (no record yet) they carry the
  /// rostered window so the applied record has a scheduled reference for
  /// lateness and the board — null for a genuinely unscheduled shift.
  DateTime? get scheduledStart => throw _privateConstructorUsedError;
  DateTime? get scheduledEnd =>
      throw _privateConstructorUsedError; // ── The proposed fix (what the employee is asking for) ──
  DateTime? get proposedClockIn => throw _privateConstructorUsedError;
  DateTime? get proposedClockOut => throw _privateConstructorUsedError;

  /// An optional target lifecycle (e.g. an absence dispute → `completed`).
  AttendanceStatus? get proposedStatus => throw _privateConstructorUsedError;

  /// The applied result, set by `DecideCorrection` on approval and copied onto
  /// the record by the Cloud Function. Null until approved.
  AttendanceResolution? get resolution =>
      throw _privateConstructorUsedError; // ── Decision stamps ──
  String? get decidedBy => throw _privateConstructorUsedError;
  String? get decidedByName => throw _privateConstructorUsedError;
  DateTime? get decidedAt => throw _privateConstructorUsedError;
  String? get decisionNote => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Admin soft-delete — the correction stays as history, lists filter it out.
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceCorrectionEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceCorrectionEntityCopyWith<AttendanceCorrectionEntity>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceCorrectionEntityCopyWith<$Res> {
  factory $AttendanceCorrectionEntityCopyWith(
    AttendanceCorrectionEntity value,
    $Res Function(AttendanceCorrectionEntity) then,
  ) =
      _$AttendanceCorrectionEntityCopyWithImpl<
        $Res,
        AttendanceCorrectionEntity
      >;
  @useResult
  $Res call({
    String id,
    String attendanceId,
    String userId,
    String? userName,
    String? branchId,
    ScheduleShift? shift,
    DateTime? date,
    String requestedBy,
    String? requestedByName,
    AttendanceCorrectionKind kind,
    RequestStatus status,
    String reason,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    AttendanceStatus? proposedStatus,
    AttendanceResolution? resolution,
    String? decidedBy,
    String? decidedByName,
    DateTime? decidedAt,
    String? decisionNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  });
}

/// @nodoc
class _$AttendanceCorrectionEntityCopyWithImpl<
  $Res,
  $Val extends AttendanceCorrectionEntity
>
    implements $AttendanceCorrectionEntityCopyWith<$Res> {
  _$AttendanceCorrectionEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceCorrectionEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? attendanceId = null,
    Object? userId = null,
    Object? userName = freezed,
    Object? branchId = freezed,
    Object? shift = freezed,
    Object? date = freezed,
    Object? requestedBy = null,
    Object? requestedByName = freezed,
    Object? kind = null,
    Object? status = null,
    Object? reason = null,
    Object? scheduledStart = freezed,
    Object? scheduledEnd = freezed,
    Object? proposedClockIn = freezed,
    Object? proposedClockOut = freezed,
    Object? proposedStatus = freezed,
    Object? resolution = freezed,
    Object? decidedBy = freezed,
    Object? decidedByName = freezed,
    Object? decidedAt = freezed,
    Object? decisionNote = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            attendanceId: null == attendanceId
                ? _value.attendanceId
                : attendanceId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            userName: freezed == userName
                ? _value.userName
                : userName // ignore: cast_nullable_to_non_nullable
                      as String?,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            shift: freezed == shift
                ? _value.shift
                : shift // ignore: cast_nullable_to_non_nullable
                      as ScheduleShift?,
            date: freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            requestedBy: null == requestedBy
                ? _value.requestedBy
                : requestedBy // ignore: cast_nullable_to_non_nullable
                      as String,
            requestedByName: freezed == requestedByName
                ? _value.requestedByName
                : requestedByName // ignore: cast_nullable_to_non_nullable
                      as String?,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as AttendanceCorrectionKind,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as RequestStatus,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String,
            scheduledStart: freezed == scheduledStart
                ? _value.scheduledStart
                : scheduledStart // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            scheduledEnd: freezed == scheduledEnd
                ? _value.scheduledEnd
                : scheduledEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            proposedClockIn: freezed == proposedClockIn
                ? _value.proposedClockIn
                : proposedClockIn // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            proposedClockOut: freezed == proposedClockOut
                ? _value.proposedClockOut
                : proposedClockOut // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            proposedStatus: freezed == proposedStatus
                ? _value.proposedStatus
                : proposedStatus // ignore: cast_nullable_to_non_nullable
                      as AttendanceStatus?,
            resolution: freezed == resolution
                ? _value.resolution
                : resolution // ignore: cast_nullable_to_non_nullable
                      as AttendanceResolution?,
            decidedBy: freezed == decidedBy
                ? _value.decidedBy
                : decidedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            decidedByName: freezed == decidedByName
                ? _value.decidedByName
                : decidedByName // ignore: cast_nullable_to_non_nullable
                      as String?,
            decidedAt: freezed == decidedAt
                ? _value.decidedAt
                : decidedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            decisionNote: freezed == decisionNote
                ? _value.decisionNote
                : decisionNote // ignore: cast_nullable_to_non_nullable
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
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceCorrectionEntityImplCopyWith<$Res>
    implements $AttendanceCorrectionEntityCopyWith<$Res> {
  factory _$$AttendanceCorrectionEntityImplCopyWith(
    _$AttendanceCorrectionEntityImpl value,
    $Res Function(_$AttendanceCorrectionEntityImpl) then,
  ) = __$$AttendanceCorrectionEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String attendanceId,
    String userId,
    String? userName,
    String? branchId,
    ScheduleShift? shift,
    DateTime? date,
    String requestedBy,
    String? requestedByName,
    AttendanceCorrectionKind kind,
    RequestStatus status,
    String reason,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    AttendanceStatus? proposedStatus,
    AttendanceResolution? resolution,
    String? decidedBy,
    String? decidedByName,
    DateTime? decidedAt,
    String? decisionNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  });
}

/// @nodoc
class __$$AttendanceCorrectionEntityImplCopyWithImpl<$Res>
    extends
        _$AttendanceCorrectionEntityCopyWithImpl<
          $Res,
          _$AttendanceCorrectionEntityImpl
        >
    implements _$$AttendanceCorrectionEntityImplCopyWith<$Res> {
  __$$AttendanceCorrectionEntityImplCopyWithImpl(
    _$AttendanceCorrectionEntityImpl _value,
    $Res Function(_$AttendanceCorrectionEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceCorrectionEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? attendanceId = null,
    Object? userId = null,
    Object? userName = freezed,
    Object? branchId = freezed,
    Object? shift = freezed,
    Object? date = freezed,
    Object? requestedBy = null,
    Object? requestedByName = freezed,
    Object? kind = null,
    Object? status = null,
    Object? reason = null,
    Object? scheduledStart = freezed,
    Object? scheduledEnd = freezed,
    Object? proposedClockIn = freezed,
    Object? proposedClockOut = freezed,
    Object? proposedStatus = freezed,
    Object? resolution = freezed,
    Object? decidedBy = freezed,
    Object? decidedByName = freezed,
    Object? decidedAt = freezed,
    Object? decisionNote = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _$AttendanceCorrectionEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        attendanceId: null == attendanceId
            ? _value.attendanceId
            : attendanceId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        userName: freezed == userName
            ? _value.userName
            : userName // ignore: cast_nullable_to_non_nullable
                  as String?,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        shift: freezed == shift
            ? _value.shift
            : shift // ignore: cast_nullable_to_non_nullable
                  as ScheduleShift?,
        date: freezed == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        requestedBy: null == requestedBy
            ? _value.requestedBy
            : requestedBy // ignore: cast_nullable_to_non_nullable
                  as String,
        requestedByName: freezed == requestedByName
            ? _value.requestedByName
            : requestedByName // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as AttendanceCorrectionKind,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as RequestStatus,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
        scheduledStart: freezed == scheduledStart
            ? _value.scheduledStart
            : scheduledStart // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        scheduledEnd: freezed == scheduledEnd
            ? _value.scheduledEnd
            : scheduledEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        proposedClockIn: freezed == proposedClockIn
            ? _value.proposedClockIn
            : proposedClockIn // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        proposedClockOut: freezed == proposedClockOut
            ? _value.proposedClockOut
            : proposedClockOut // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        proposedStatus: freezed == proposedStatus
            ? _value.proposedStatus
            : proposedStatus // ignore: cast_nullable_to_non_nullable
                  as AttendanceStatus?,
        resolution: freezed == resolution
            ? _value.resolution
            : resolution // ignore: cast_nullable_to_non_nullable
                  as AttendanceResolution?,
        decidedBy: freezed == decidedBy
            ? _value.decidedBy
            : decidedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        decidedByName: freezed == decidedByName
            ? _value.decidedByName
            : decidedByName // ignore: cast_nullable_to_non_nullable
                  as String?,
        decidedAt: freezed == decidedAt
            ? _value.decidedAt
            : decidedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        decisionNote: freezed == decisionNote
            ? _value.decisionNote
            : decisionNote // ignore: cast_nullable_to_non_nullable
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
      ),
    );
  }
}

/// @nodoc

class _$AttendanceCorrectionEntityImpl extends _AttendanceCorrectionEntity {
  const _$AttendanceCorrectionEntityImpl({
    required this.id,
    required this.attendanceId,
    required this.userId,
    this.userName,
    this.branchId,
    this.shift,
    this.date,
    required this.requestedBy,
    this.requestedByName,
    required this.kind,
    this.status = RequestStatus.pending,
    required this.reason,
    this.scheduledStart,
    this.scheduledEnd,
    this.proposedClockIn,
    this.proposedClockOut,
    this.proposedStatus,
    this.resolution,
    this.decidedBy,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : super._();

  @override
  final String id;

  /// The parent record's deterministic id (`{uid}_{yyyyMMdd}_{shift}`).
  @override
  final String attendanceId;

  /// Whose attendance this is (== [requestedBy] — the filer is the record's
  /// own employee; enforced by the create rule).
  @override
  final String userId;
  @override
  final String? userName;
  @override
  final String? branchId;

  /// Denormalized for the reviewer's queue row (avoids a record fetch per row).
  @override
  final ScheduleShift? shift;
  @override
  final DateTime? date;
  @override
  final String requestedBy;
  @override
  final String? requestedByName;
  @override
  final AttendanceCorrectionKind kind;
  @override
  @JsonKey()
  final RequestStatus status;

  /// Why the record is wrong (the employee's explanation) — always required.
  @override
  final String reason;

  /// The scheduled window this correction is measured against. On a correction
  /// to an **existing** record these are redundant (the record already has
  /// them). On a **missed-punch** materialization (no record yet) they carry the
  /// rostered window so the applied record has a scheduled reference for
  /// lateness and the board — null for a genuinely unscheduled shift.
  @override
  final DateTime? scheduledStart;
  @override
  final DateTime? scheduledEnd;
  // ── The proposed fix (what the employee is asking for) ──
  @override
  final DateTime? proposedClockIn;
  @override
  final DateTime? proposedClockOut;

  /// An optional target lifecycle (e.g. an absence dispute → `completed`).
  @override
  final AttendanceStatus? proposedStatus;

  /// The applied result, set by `DecideCorrection` on approval and copied onto
  /// the record by the Cloud Function. Null until approved.
  @override
  final AttendanceResolution? resolution;
  // ── Decision stamps ──
  @override
  final String? decidedBy;
  @override
  final String? decidedByName;
  @override
  final DateTime? decidedAt;
  @override
  final String? decisionNote;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  /// Admin soft-delete — the correction stays as history, lists filter it out.
  @override
  final DateTime? deletedAt;

  @override
  String toString() {
    return 'AttendanceCorrectionEntity(id: $id, attendanceId: $attendanceId, userId: $userId, userName: $userName, branchId: $branchId, shift: $shift, date: $date, requestedBy: $requestedBy, requestedByName: $requestedByName, kind: $kind, status: $status, reason: $reason, scheduledStart: $scheduledStart, scheduledEnd: $scheduledEnd, proposedClockIn: $proposedClockIn, proposedClockOut: $proposedClockOut, proposedStatus: $proposedStatus, resolution: $resolution, decidedBy: $decidedBy, decidedByName: $decidedByName, decidedAt: $decidedAt, decisionNote: $decisionNote, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceCorrectionEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.attendanceId, attendanceId) ||
                other.attendanceId == attendanceId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.requestedBy, requestedBy) ||
                other.requestedBy == requestedBy) &&
            (identical(other.requestedByName, requestedByName) ||
                other.requestedByName == requestedByName) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.scheduledStart, scheduledStart) ||
                other.scheduledStart == scheduledStart) &&
            (identical(other.scheduledEnd, scheduledEnd) ||
                other.scheduledEnd == scheduledEnd) &&
            (identical(other.proposedClockIn, proposedClockIn) ||
                other.proposedClockIn == proposedClockIn) &&
            (identical(other.proposedClockOut, proposedClockOut) ||
                other.proposedClockOut == proposedClockOut) &&
            (identical(other.proposedStatus, proposedStatus) ||
                other.proposedStatus == proposedStatus) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution) &&
            (identical(other.decidedBy, decidedBy) ||
                other.decidedBy == decidedBy) &&
            (identical(other.decidedByName, decidedByName) ||
                other.decidedByName == decidedByName) &&
            (identical(other.decidedAt, decidedAt) ||
                other.decidedAt == decidedAt) &&
            (identical(other.decisionNote, decisionNote) ||
                other.decisionNote == decisionNote) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    attendanceId,
    userId,
    userName,
    branchId,
    shift,
    date,
    requestedBy,
    requestedByName,
    kind,
    status,
    reason,
    scheduledStart,
    scheduledEnd,
    proposedClockIn,
    proposedClockOut,
    proposedStatus,
    resolution,
    decidedBy,
    decidedByName,
    decidedAt,
    decisionNote,
    createdAt,
    updatedAt,
    deletedAt,
  ]);

  /// Create a copy of AttendanceCorrectionEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceCorrectionEntityImplCopyWith<_$AttendanceCorrectionEntityImpl>
  get copyWith =>
      __$$AttendanceCorrectionEntityImplCopyWithImpl<
        _$AttendanceCorrectionEntityImpl
      >(this, _$identity);
}

abstract class _AttendanceCorrectionEntity extends AttendanceCorrectionEntity {
  const factory _AttendanceCorrectionEntity({
    required final String id,
    required final String attendanceId,
    required final String userId,
    final String? userName,
    final String? branchId,
    final ScheduleShift? shift,
    final DateTime? date,
    required final String requestedBy,
    final String? requestedByName,
    required final AttendanceCorrectionKind kind,
    final RequestStatus status,
    required final String reason,
    final DateTime? scheduledStart,
    final DateTime? scheduledEnd,
    final DateTime? proposedClockIn,
    final DateTime? proposedClockOut,
    final AttendanceStatus? proposedStatus,
    final AttendanceResolution? resolution,
    final String? decidedBy,
    final String? decidedByName,
    final DateTime? decidedAt,
    final String? decisionNote,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? deletedAt,
  }) = _$AttendanceCorrectionEntityImpl;
  const _AttendanceCorrectionEntity._() : super._();

  @override
  String get id;

  /// The parent record's deterministic id (`{uid}_{yyyyMMdd}_{shift}`).
  @override
  String get attendanceId;

  /// Whose attendance this is (== [requestedBy] — the filer is the record's
  /// own employee; enforced by the create rule).
  @override
  String get userId;
  @override
  String? get userName;
  @override
  String? get branchId;

  /// Denormalized for the reviewer's queue row (avoids a record fetch per row).
  @override
  ScheduleShift? get shift;
  @override
  DateTime? get date;
  @override
  String get requestedBy;
  @override
  String? get requestedByName;
  @override
  AttendanceCorrectionKind get kind;
  @override
  RequestStatus get status;

  /// Why the record is wrong (the employee's explanation) — always required.
  @override
  String get reason;

  /// The scheduled window this correction is measured against. On a correction
  /// to an **existing** record these are redundant (the record already has
  /// them). On a **missed-punch** materialization (no record yet) they carry the
  /// rostered window so the applied record has a scheduled reference for
  /// lateness and the board — null for a genuinely unscheduled shift.
  @override
  DateTime? get scheduledStart;
  @override
  DateTime? get scheduledEnd; // ── The proposed fix (what the employee is asking for) ──
  @override
  DateTime? get proposedClockIn;
  @override
  DateTime? get proposedClockOut;

  /// An optional target lifecycle (e.g. an absence dispute → `completed`).
  @override
  AttendanceStatus? get proposedStatus;

  /// The applied result, set by `DecideCorrection` on approval and copied onto
  /// the record by the Cloud Function. Null until approved.
  @override
  AttendanceResolution? get resolution; // ── Decision stamps ──
  @override
  String? get decidedBy;
  @override
  String? get decidedByName;
  @override
  DateTime? get decidedAt;
  @override
  String? get decisionNote;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Admin soft-delete — the correction stays as history, lists filter it out.
  @override
  DateTime? get deletedAt;

  /// Create a copy of AttendanceCorrectionEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceCorrectionEntityImplCopyWith<_$AttendanceCorrectionEntityImpl>
  get copyWith => throw _privateConstructorUsedError;
}
