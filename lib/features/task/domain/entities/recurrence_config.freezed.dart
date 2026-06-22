// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurrence_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RecurrenceConfig {
  RecurrenceFrequency get frequency => throw _privateConstructorUsedError;

  /// How many units between occurrences (e.g. interval=2 + daily = every 2 days).
  int get interval => throw _privateConstructorUsedError;

  /// Target weekday for weekly recurrence: DateTime.monday = 1 … DateTime.sunday = 7.
  int get weekday => throw _privateConstructorUsedError;

  /// Hour of day the task should start (24h, default 9 = 9 AM).
  int get hour => throw _privateConstructorUsedError;
  int get minute => throw _privateConstructorUsedError;

  /// Create a copy of RecurrenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecurrenceConfigCopyWith<RecurrenceConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurrenceConfigCopyWith<$Res> {
  factory $RecurrenceConfigCopyWith(
    RecurrenceConfig value,
    $Res Function(RecurrenceConfig) then,
  ) = _$RecurrenceConfigCopyWithImpl<$Res, RecurrenceConfig>;
  @useResult
  $Res call({
    RecurrenceFrequency frequency,
    int interval,
    int weekday,
    int hour,
    int minute,
  });
}

/// @nodoc
class _$RecurrenceConfigCopyWithImpl<$Res, $Val extends RecurrenceConfig>
    implements $RecurrenceConfigCopyWith<$Res> {
  _$RecurrenceConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecurrenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? frequency = null,
    Object? interval = null,
    Object? weekday = null,
    Object? hour = null,
    Object? minute = null,
  }) {
    return _then(
      _value.copyWith(
            frequency: null == frequency
                ? _value.frequency
                : frequency // ignore: cast_nullable_to_non_nullable
                      as RecurrenceFrequency,
            interval: null == interval
                ? _value.interval
                : interval // ignore: cast_nullable_to_non_nullable
                      as int,
            weekday: null == weekday
                ? _value.weekday
                : weekday // ignore: cast_nullable_to_non_nullable
                      as int,
            hour: null == hour
                ? _value.hour
                : hour // ignore: cast_nullable_to_non_nullable
                      as int,
            minute: null == minute
                ? _value.minute
                : minute // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecurrenceConfigImplCopyWith<$Res>
    implements $RecurrenceConfigCopyWith<$Res> {
  factory _$$RecurrenceConfigImplCopyWith(
    _$RecurrenceConfigImpl value,
    $Res Function(_$RecurrenceConfigImpl) then,
  ) = __$$RecurrenceConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    RecurrenceFrequency frequency,
    int interval,
    int weekday,
    int hour,
    int minute,
  });
}

/// @nodoc
class __$$RecurrenceConfigImplCopyWithImpl<$Res>
    extends _$RecurrenceConfigCopyWithImpl<$Res, _$RecurrenceConfigImpl>
    implements _$$RecurrenceConfigImplCopyWith<$Res> {
  __$$RecurrenceConfigImplCopyWithImpl(
    _$RecurrenceConfigImpl _value,
    $Res Function(_$RecurrenceConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecurrenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? frequency = null,
    Object? interval = null,
    Object? weekday = null,
    Object? hour = null,
    Object? minute = null,
  }) {
    return _then(
      _$RecurrenceConfigImpl(
        frequency: null == frequency
            ? _value.frequency
            : frequency // ignore: cast_nullable_to_non_nullable
                  as RecurrenceFrequency,
        interval: null == interval
            ? _value.interval
            : interval // ignore: cast_nullable_to_non_nullable
                  as int,
        weekday: null == weekday
            ? _value.weekday
            : weekday // ignore: cast_nullable_to_non_nullable
                  as int,
        hour: null == hour
            ? _value.hour
            : hour // ignore: cast_nullable_to_non_nullable
                  as int,
        minute: null == minute
            ? _value.minute
            : minute // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$RecurrenceConfigImpl extends _RecurrenceConfig {
  const _$RecurrenceConfigImpl({
    required this.frequency,
    this.interval = 1,
    this.weekday = 1,
    this.hour = 9,
    this.minute = 0,
  }) : super._();

  @override
  final RecurrenceFrequency frequency;

  /// How many units between occurrences (e.g. interval=2 + daily = every 2 days).
  @override
  @JsonKey()
  final int interval;

  /// Target weekday for weekly recurrence: DateTime.monday = 1 … DateTime.sunday = 7.
  @override
  @JsonKey()
  final int weekday;

  /// Hour of day the task should start (24h, default 9 = 9 AM).
  @override
  @JsonKey()
  final int hour;
  @override
  @JsonKey()
  final int minute;

  @override
  String toString() {
    return 'RecurrenceConfig(frequency: $frequency, interval: $interval, weekday: $weekday, hour: $hour, minute: $minute)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurrenceConfigImpl &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency) &&
            (identical(other.interval, interval) ||
                other.interval == interval) &&
            (identical(other.weekday, weekday) || other.weekday == weekday) &&
            (identical(other.hour, hour) || other.hour == hour) &&
            (identical(other.minute, minute) || other.minute == minute));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, frequency, interval, weekday, hour, minute);

  /// Create a copy of RecurrenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurrenceConfigImplCopyWith<_$RecurrenceConfigImpl> get copyWith =>
      __$$RecurrenceConfigImplCopyWithImpl<_$RecurrenceConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _RecurrenceConfig extends RecurrenceConfig {
  const factory _RecurrenceConfig({
    required final RecurrenceFrequency frequency,
    final int interval,
    final int weekday,
    final int hour,
    final int minute,
  }) = _$RecurrenceConfigImpl;
  const _RecurrenceConfig._() : super._();

  @override
  RecurrenceFrequency get frequency;

  /// How many units between occurrences (e.g. interval=2 + daily = every 2 days).
  @override
  int get interval;

  /// Target weekday for weekly recurrence: DateTime.monday = 1 … DateTime.sunday = 7.
  @override
  int get weekday;

  /// Hour of day the task should start (24h, default 9 = 9 AM).
  @override
  int get hour;
  @override
  int get minute;

  /// Create a copy of RecurrenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecurrenceConfigImplCopyWith<_$RecurrenceConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
