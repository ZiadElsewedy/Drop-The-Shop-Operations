// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChecklistItem {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  bool get isRequired => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistItemCopyWith<ChecklistItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistItemCopyWith<$Res> {
  factory $ChecklistItemCopyWith(
    ChecklistItem value,
    $Res Function(ChecklistItem) then,
  ) = _$ChecklistItemCopyWithImpl<$Res, ChecklistItem>;
  @useResult
  $Res call({
    String id,
    String title,
    bool isRequired,
    bool completed,
    DateTime? completedAt,
  });
}

/// @nodoc
class _$ChecklistItemCopyWithImpl<$Res, $Val extends ChecklistItem>
    implements $ChecklistItemCopyWith<$Res> {
  _$ChecklistItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isRequired = null,
    Object? completed = null,
    Object? completedAt = freezed,
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
            isRequired: null == isRequired
                ? _value.isRequired
                : isRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
            completed: null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                      as bool,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChecklistItemImplCopyWith<$Res>
    implements $ChecklistItemCopyWith<$Res> {
  factory _$$ChecklistItemImplCopyWith(
    _$ChecklistItemImpl value,
    $Res Function(_$ChecklistItemImpl) then,
  ) = __$$ChecklistItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    bool isRequired,
    bool completed,
    DateTime? completedAt,
  });
}

/// @nodoc
class __$$ChecklistItemImplCopyWithImpl<$Res>
    extends _$ChecklistItemCopyWithImpl<$Res, _$ChecklistItemImpl>
    implements _$$ChecklistItemImplCopyWith<$Res> {
  __$$ChecklistItemImplCopyWithImpl(
    _$ChecklistItemImpl _value,
    $Res Function(_$ChecklistItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isRequired = null,
    Object? completed = null,
    Object? completedAt = freezed,
  }) {
    return _then(
      _$ChecklistItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        isRequired: null == isRequired
            ? _value.isRequired
            : isRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        completed: null == completed
            ? _value.completed
            : completed // ignore: cast_nullable_to_non_nullable
                  as bool,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$ChecklistItemImpl implements _ChecklistItem {
  const _$ChecklistItemImpl({
    required this.id,
    required this.title,
    this.isRequired = true,
    this.completed = false,
    this.completedAt,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final bool isRequired;
  @override
  @JsonKey()
  final bool completed;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'ChecklistItem(id: $id, title: $title, isRequired: $isRequired, completed: $completed, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isRequired, isRequired) ||
                other.isRequired == isRequired) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, isRequired, completed, completedAt);

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistItemImplCopyWith<_$ChecklistItemImpl> get copyWith =>
      __$$ChecklistItemImplCopyWithImpl<_$ChecklistItemImpl>(this, _$identity);
}

abstract class _ChecklistItem implements ChecklistItem {
  const factory _ChecklistItem({
    required final String id,
    required final String title,
    final bool isRequired,
    final bool completed,
    final DateTime? completedAt,
  }) = _$ChecklistItemImpl;

  @override
  String get id;
  @override
  String get title;
  @override
  bool get isRequired;
  @override
  bool get completed;
  @override
  DateTime? get completedAt;

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistItemImplCopyWith<_$ChecklistItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ChecklistItemTemplate {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  bool get isRequired => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistItemTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistItemTemplateCopyWith<ChecklistItemTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistItemTemplateCopyWith<$Res> {
  factory $ChecklistItemTemplateCopyWith(
    ChecklistItemTemplate value,
    $Res Function(ChecklistItemTemplate) then,
  ) = _$ChecklistItemTemplateCopyWithImpl<$Res, ChecklistItemTemplate>;
  @useResult
  $Res call({String id, String title, bool isRequired});
}

/// @nodoc
class _$ChecklistItemTemplateCopyWithImpl<
  $Res,
  $Val extends ChecklistItemTemplate
>
    implements $ChecklistItemTemplateCopyWith<$Res> {
  _$ChecklistItemTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistItemTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isRequired = null,
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
            isRequired: null == isRequired
                ? _value.isRequired
                : isRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChecklistItemTemplateImplCopyWith<$Res>
    implements $ChecklistItemTemplateCopyWith<$Res> {
  factory _$$ChecklistItemTemplateImplCopyWith(
    _$ChecklistItemTemplateImpl value,
    $Res Function(_$ChecklistItemTemplateImpl) then,
  ) = __$$ChecklistItemTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, bool isRequired});
}

/// @nodoc
class __$$ChecklistItemTemplateImplCopyWithImpl<$Res>
    extends
        _$ChecklistItemTemplateCopyWithImpl<$Res, _$ChecklistItemTemplateImpl>
    implements _$$ChecklistItemTemplateImplCopyWith<$Res> {
  __$$ChecklistItemTemplateImplCopyWithImpl(
    _$ChecklistItemTemplateImpl _value,
    $Res Function(_$ChecklistItemTemplateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChecklistItemTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isRequired = null,
  }) {
    return _then(
      _$ChecklistItemTemplateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        isRequired: null == isRequired
            ? _value.isRequired
            : isRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ChecklistItemTemplateImpl extends _ChecklistItemTemplate {
  const _$ChecklistItemTemplateImpl({
    required this.id,
    required this.title,
    this.isRequired = true,
  }) : super._();

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final bool isRequired;

  @override
  String toString() {
    return 'ChecklistItemTemplate(id: $id, title: $title, isRequired: $isRequired)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistItemTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isRequired, isRequired) ||
                other.isRequired == isRequired));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title, isRequired);

  /// Create a copy of ChecklistItemTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistItemTemplateImplCopyWith<_$ChecklistItemTemplateImpl>
  get copyWith =>
      __$$ChecklistItemTemplateImplCopyWithImpl<_$ChecklistItemTemplateImpl>(
        this,
        _$identity,
      );
}

abstract class _ChecklistItemTemplate extends ChecklistItemTemplate {
  const factory _ChecklistItemTemplate({
    required final String id,
    required final String title,
    final bool isRequired,
  }) = _$ChecklistItemTemplateImpl;
  const _ChecklistItemTemplate._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  bool get isRequired;

  /// Create a copy of ChecklistItemTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistItemTemplateImplCopyWith<_$ChecklistItemTemplateImpl>
  get copyWith => throw _privateConstructorUsedError;
}
