// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ActivityEntry {
  /// The [TaskStatus.value] string after the transition.
  String get status => throw _privateConstructorUsedError;

  /// uid of the person who triggered the change.
  String get actorId => throw _privateConstructorUsedError;

  /// Denormalised display name (best-effort; falls back to uid).
  String? get actorName => throw _privateConstructorUsedError;
  DateTime get at => throw _privateConstructorUsedError;

  /// Optional note left with the action (review note, completion note, etc.).
  String? get note => throw _privateConstructorUsedError;

  /// Media attached to this event (images / videos).
  List<TaskAttachment> get attachments => throw _privateConstructorUsedError;

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActivityEntryCopyWith<ActivityEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActivityEntryCopyWith<$Res> {
  factory $ActivityEntryCopyWith(
    ActivityEntry value,
    $Res Function(ActivityEntry) then,
  ) = _$ActivityEntryCopyWithImpl<$Res, ActivityEntry>;
  @useResult
  $Res call({
    String status,
    String actorId,
    String? actorName,
    DateTime at,
    String? note,
    List<TaskAttachment> attachments,
  });
}

/// @nodoc
class _$ActivityEntryCopyWithImpl<$Res, $Val extends ActivityEntry>
    implements $ActivityEntryCopyWith<$Res> {
  _$ActivityEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actorId = null,
    Object? actorName = freezed,
    Object? at = null,
    Object? note = freezed,
    Object? attachments = null,
  }) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            actorId: null == actorId
                ? _value.actorId
                : actorId // ignore: cast_nullable_to_non_nullable
                      as String,
            actorName: freezed == actorName
                ? _value.actorName
                : actorName // ignore: cast_nullable_to_non_nullable
                      as String?,
            at: null == at
                ? _value.at
                : at // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            attachments: null == attachments
                ? _value.attachments
                : attachments // ignore: cast_nullable_to_non_nullable
                      as List<TaskAttachment>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ActivityEntryImplCopyWith<$Res>
    implements $ActivityEntryCopyWith<$Res> {
  factory _$$ActivityEntryImplCopyWith(
    _$ActivityEntryImpl value,
    $Res Function(_$ActivityEntryImpl) then,
  ) = __$$ActivityEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String status,
    String actorId,
    String? actorName,
    DateTime at,
    String? note,
    List<TaskAttachment> attachments,
  });
}

/// @nodoc
class __$$ActivityEntryImplCopyWithImpl<$Res>
    extends _$ActivityEntryCopyWithImpl<$Res, _$ActivityEntryImpl>
    implements _$$ActivityEntryImplCopyWith<$Res> {
  __$$ActivityEntryImplCopyWithImpl(
    _$ActivityEntryImpl _value,
    $Res Function(_$ActivityEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actorId = null,
    Object? actorName = freezed,
    Object? at = null,
    Object? note = freezed,
    Object? attachments = null,
  }) {
    return _then(
      _$ActivityEntryImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        actorId: null == actorId
            ? _value.actorId
            : actorId // ignore: cast_nullable_to_non_nullable
                  as String,
        actorName: freezed == actorName
            ? _value.actorName
            : actorName // ignore: cast_nullable_to_non_nullable
                  as String?,
        at: null == at
            ? _value.at
            : at // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        attachments: null == attachments
            ? _value._attachments
            : attachments // ignore: cast_nullable_to_non_nullable
                  as List<TaskAttachment>,
      ),
    );
  }
}

/// @nodoc

class _$ActivityEntryImpl implements _ActivityEntry {
  const _$ActivityEntryImpl({
    required this.status,
    required this.actorId,
    this.actorName,
    required this.at,
    this.note,
    final List<TaskAttachment> attachments = const <TaskAttachment>[],
  }) : _attachments = attachments;

  /// The [TaskStatus.value] string after the transition.
  @override
  final String status;

  /// uid of the person who triggered the change.
  @override
  final String actorId;

  /// Denormalised display name (best-effort; falls back to uid).
  @override
  final String? actorName;
  @override
  final DateTime at;

  /// Optional note left with the action (review note, completion note, etc.).
  @override
  final String? note;

  /// Media attached to this event (images / videos).
  final List<TaskAttachment> _attachments;

  /// Media attached to this event (images / videos).
  @override
  @JsonKey()
  List<TaskAttachment> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  @override
  String toString() {
    return 'ActivityEntry(status: $status, actorId: $actorId, actorName: $actorName, at: $at, note: $note, attachments: $attachments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActivityEntryImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actorId, actorId) || other.actorId == actorId) &&
            (identical(other.actorName, actorName) ||
                other.actorName == actorName) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality().equals(
              other._attachments,
              _attachments,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    actorId,
    actorName,
    at,
    note,
    const DeepCollectionEquality().hash(_attachments),
  );

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActivityEntryImplCopyWith<_$ActivityEntryImpl> get copyWith =>
      __$$ActivityEntryImplCopyWithImpl<_$ActivityEntryImpl>(this, _$identity);
}

abstract class _ActivityEntry implements ActivityEntry {
  const factory _ActivityEntry({
    required final String status,
    required final String actorId,
    final String? actorName,
    required final DateTime at,
    final String? note,
    final List<TaskAttachment> attachments,
  }) = _$ActivityEntryImpl;

  /// The [TaskStatus.value] string after the transition.
  @override
  String get status;

  /// uid of the person who triggered the change.
  @override
  String get actorId;

  /// Denormalised display name (best-effort; falls back to uid).
  @override
  String? get actorName;
  @override
  DateTime get at;

  /// Optional note left with the action (review note, completion note, etc.).
  @override
  String? get note;

  /// Media attached to this event (images / videos).
  @override
  List<TaskAttachment> get attachments;

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActivityEntryImplCopyWith<_$ActivityEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
