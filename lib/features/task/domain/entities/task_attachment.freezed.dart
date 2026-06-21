// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TaskAttachment {
  /// Unique attachment id (also the Storage filename stem).
  String get id => throw _privateConstructorUsedError;

  /// Storage download URL.
  AttachmentType get type => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;

  /// uid of the uploader.
  String get uploadedBy => throw _privateConstructorUsedError;

  /// Denormalised uploader display name (best-effort).
  String? get uploadedByName => throw _privateConstructorUsedError;

  /// Video length in milliseconds (best-effort, captured at pick). Null for
  /// images and for videos uploaded before duration capture existed.
  int? get durationMs => throw _privateConstructorUsedError;

  /// Create a copy of TaskAttachment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskAttachmentCopyWith<TaskAttachment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskAttachmentCopyWith<$Res> {
  factory $TaskAttachmentCopyWith(
    TaskAttachment value,
    $Res Function(TaskAttachment) then,
  ) = _$TaskAttachmentCopyWithImpl<$Res, TaskAttachment>;
  @useResult
  $Res call({
    String id,
    AttachmentType type,
    String url,
    DateTime uploadedAt,
    String uploadedBy,
    String? uploadedByName,
    int? durationMs,
  });
}

/// @nodoc
class _$TaskAttachmentCopyWithImpl<$Res, $Val extends TaskAttachment>
    implements $TaskAttachmentCopyWith<$Res> {
  _$TaskAttachmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskAttachment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? url = null,
    Object? uploadedAt = null,
    Object? uploadedBy = null,
    Object? uploadedByName = freezed,
    Object? durationMs = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as AttachmentType,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            uploadedBy: null == uploadedBy
                ? _value.uploadedBy
                : uploadedBy // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadedByName: freezed == uploadedByName
                ? _value.uploadedByName
                : uploadedByName // ignore: cast_nullable_to_non_nullable
                      as String?,
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskAttachmentImplCopyWith<$Res>
    implements $TaskAttachmentCopyWith<$Res> {
  factory _$$TaskAttachmentImplCopyWith(
    _$TaskAttachmentImpl value,
    $Res Function(_$TaskAttachmentImpl) then,
  ) = __$$TaskAttachmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    AttachmentType type,
    String url,
    DateTime uploadedAt,
    String uploadedBy,
    String? uploadedByName,
    int? durationMs,
  });
}

/// @nodoc
class __$$TaskAttachmentImplCopyWithImpl<$Res>
    extends _$TaskAttachmentCopyWithImpl<$Res, _$TaskAttachmentImpl>
    implements _$$TaskAttachmentImplCopyWith<$Res> {
  __$$TaskAttachmentImplCopyWithImpl(
    _$TaskAttachmentImpl _value,
    $Res Function(_$TaskAttachmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskAttachment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? url = null,
    Object? uploadedAt = null,
    Object? uploadedBy = null,
    Object? uploadedByName = freezed,
    Object? durationMs = freezed,
  }) {
    return _then(
      _$TaskAttachmentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as AttachmentType,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        uploadedBy: null == uploadedBy
            ? _value.uploadedBy
            : uploadedBy // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadedByName: freezed == uploadedByName
            ? _value.uploadedByName
            : uploadedByName // ignore: cast_nullable_to_non_nullable
                  as String?,
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$TaskAttachmentImpl extends _TaskAttachment {
  const _$TaskAttachmentImpl({
    required this.id,
    required this.type,
    required this.url,
    required this.uploadedAt,
    required this.uploadedBy,
    this.uploadedByName,
    this.durationMs,
  }) : super._();

  /// Unique attachment id (also the Storage filename stem).
  @override
  final String id;

  /// Storage download URL.
  @override
  final AttachmentType type;
  @override
  final String url;
  @override
  final DateTime uploadedAt;

  /// uid of the uploader.
  @override
  final String uploadedBy;

  /// Denormalised uploader display name (best-effort).
  @override
  final String? uploadedByName;

  /// Video length in milliseconds (best-effort, captured at pick). Null for
  /// images and for videos uploaded before duration capture existed.
  @override
  final int? durationMs;

  @override
  String toString() {
    return 'TaskAttachment(id: $id, type: $type, url: $url, uploadedAt: $uploadedAt, uploadedBy: $uploadedBy, uploadedByName: $uploadedByName, durationMs: $durationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskAttachmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt) &&
            (identical(other.uploadedBy, uploadedBy) ||
                other.uploadedBy == uploadedBy) &&
            (identical(other.uploadedByName, uploadedByName) ||
                other.uploadedByName == uploadedByName) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    url,
    uploadedAt,
    uploadedBy,
    uploadedByName,
    durationMs,
  );

  /// Create a copy of TaskAttachment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskAttachmentImplCopyWith<_$TaskAttachmentImpl> get copyWith =>
      __$$TaskAttachmentImplCopyWithImpl<_$TaskAttachmentImpl>(
        this,
        _$identity,
      );
}

abstract class _TaskAttachment extends TaskAttachment {
  const factory _TaskAttachment({
    required final String id,
    required final AttachmentType type,
    required final String url,
    required final DateTime uploadedAt,
    required final String uploadedBy,
    final String? uploadedByName,
    final int? durationMs,
  }) = _$TaskAttachmentImpl;
  const _TaskAttachment._() : super._();

  /// Unique attachment id (also the Storage filename stem).
  @override
  String get id;

  /// Storage download URL.
  @override
  AttachmentType get type;
  @override
  String get url;
  @override
  DateTime get uploadedAt;

  /// uid of the uploader.
  @override
  String get uploadedBy;

  /// Denormalised uploader display name (best-effort).
  @override
  String? get uploadedByName;

  /// Video length in milliseconds (best-effort, captured at pick). Null for
  /// images and for videos uploaded before duration capture existed.
  @override
  int? get durationMs;

  /// Create a copy of TaskAttachment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskAttachmentImplCopyWith<_$TaskAttachmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
