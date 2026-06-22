// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$NotificationEntity {
  String get id => throw _privateConstructorUsedError;
  String get recipientUid => throw _privateConstructorUsedError;

  /// Who triggered it (null for system-generated). For a task event this is
  /// the acting manager/employee; for a broadcast, the sender.
  String? get senderUid => throw _privateConstructorUsedError;
  NotificationType get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// When the recipient read it; null while unread.
  DateTime? get readAt => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationEntityCopyWith<NotificationEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationEntityCopyWith<$Res> {
  factory $NotificationEntityCopyWith(
    NotificationEntity value,
    $Res Function(NotificationEntity) then,
  ) = _$NotificationEntityCopyWithImpl<$Res, NotificationEntity>;
  @useResult
  $Res call({
    String id,
    String recipientUid,
    String? senderUid,
    NotificationType type,
    String title,
    String body,
    DateTime createdAt,
    DateTime? readAt,
    Map<String, dynamic> payload,
  });
}

/// @nodoc
class _$NotificationEntityCopyWithImpl<$Res, $Val extends NotificationEntity>
    implements $NotificationEntityCopyWith<$Res> {
  _$NotificationEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? recipientUid = null,
    Object? senderUid = freezed,
    Object? type = null,
    Object? title = null,
    Object? body = null,
    Object? createdAt = null,
    Object? readAt = freezed,
    Object? payload = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            recipientUid: null == recipientUid
                ? _value.recipientUid
                : recipientUid // ignore: cast_nullable_to_non_nullable
                      as String,
            senderUid: freezed == senderUid
                ? _value.senderUid
                : senderUid // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as NotificationType,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            body: null == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            readAt: freezed == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            payload: null == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationEntityImplCopyWith<$Res>
    implements $NotificationEntityCopyWith<$Res> {
  factory _$$NotificationEntityImplCopyWith(
    _$NotificationEntityImpl value,
    $Res Function(_$NotificationEntityImpl) then,
  ) = __$$NotificationEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String recipientUid,
    String? senderUid,
    NotificationType type,
    String title,
    String body,
    DateTime createdAt,
    DateTime? readAt,
    Map<String, dynamic> payload,
  });
}

/// @nodoc
class __$$NotificationEntityImplCopyWithImpl<$Res>
    extends _$NotificationEntityCopyWithImpl<$Res, _$NotificationEntityImpl>
    implements _$$NotificationEntityImplCopyWith<$Res> {
  __$$NotificationEntityImplCopyWithImpl(
    _$NotificationEntityImpl _value,
    $Res Function(_$NotificationEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? recipientUid = null,
    Object? senderUid = freezed,
    Object? type = null,
    Object? title = null,
    Object? body = null,
    Object? createdAt = null,
    Object? readAt = freezed,
    Object? payload = null,
  }) {
    return _then(
      _$NotificationEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        recipientUid: null == recipientUid
            ? _value.recipientUid
            : recipientUid // ignore: cast_nullable_to_non_nullable
                  as String,
        senderUid: freezed == senderUid
            ? _value.senderUid
            : senderUid // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as NotificationType,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        body: null == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        readAt: freezed == readAt
            ? _value.readAt
            : readAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        payload: null == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc

class _$NotificationEntityImpl extends _NotificationEntity {
  const _$NotificationEntityImpl({
    required this.id,
    required this.recipientUid,
    this.senderUid,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    final Map<String, dynamic> payload = const <String, dynamic>{},
  }) : _payload = payload,
       super._();

  @override
  final String id;
  @override
  final String recipientUid;

  /// Who triggered it (null for system-generated). For a task event this is
  /// the acting manager/employee; for a broadcast, the sender.
  @override
  final String? senderUid;
  @override
  final NotificationType type;
  @override
  final String title;
  @override
  final String body;
  @override
  final DateTime createdAt;

  /// When the recipient read it; null while unread.
  @override
  final DateTime? readAt;
  final Map<String, dynamic> _payload;
  @override
  @JsonKey()
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  String toString() {
    return 'NotificationEntity(id: $id, recipientUid: $recipientUid, senderUid: $senderUid, type: $type, title: $title, body: $body, createdAt: $createdAt, readAt: $readAt, payload: $payload)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.recipientUid, recipientUid) ||
                other.recipientUid == recipientUid) &&
            (identical(other.senderUid, senderUid) ||
                other.senderUid == senderUid) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            const DeepCollectionEquality().equals(other._payload, _payload));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    recipientUid,
    senderUid,
    type,
    title,
    body,
    createdAt,
    readAt,
    const DeepCollectionEquality().hash(_payload),
  );

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationEntityImplCopyWith<_$NotificationEntityImpl> get copyWith =>
      __$$NotificationEntityImplCopyWithImpl<_$NotificationEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _NotificationEntity extends NotificationEntity {
  const factory _NotificationEntity({
    required final String id,
    required final String recipientUid,
    final String? senderUid,
    required final NotificationType type,
    required final String title,
    required final String body,
    required final DateTime createdAt,
    final DateTime? readAt,
    final Map<String, dynamic> payload,
  }) = _$NotificationEntityImpl;
  const _NotificationEntity._() : super._();

  @override
  String get id;
  @override
  String get recipientUid;

  /// Who triggered it (null for system-generated). For a task event this is
  /// the acting manager/employee; for a broadcast, the sender.
  @override
  String? get senderUid;
  @override
  NotificationType get type;
  @override
  String get title;
  @override
  String get body;
  @override
  DateTime get createdAt;

  /// When the recipient read it; null while unread.
  @override
  DateTime? get readAt;
  @override
  Map<String, dynamic> get payload;

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationEntityImplCopyWith<_$NotificationEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
