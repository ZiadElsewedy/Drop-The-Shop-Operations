// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'statistics_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$StatisticsEntity {
  // ── Admin (global) ──
  int get totalBranches => throw _privateConstructorUsedError;
  int get totalManagers => throw _privateConstructorUsedError;
  int get totalEmployees => throw _privateConstructorUsedError;
  int get pendingApprovals => throw _privateConstructorUsedError;
  int get branchesWithoutManagers =>
      throw _privateConstructorUsedError; // ── Manager (own branch) ──
  int get employeesInBranch => throw _privateConstructorUsedError;
  int get morningShiftEmployees => throw _privateConstructorUsedError;
  int get nightShiftEmployees => throw _privateConstructorUsedError;
  int get dailyTasks => throw _privateConstructorUsedError;
  int get specialTasks =>
      throw _privateConstructorUsedError; // ── Tasks (shared, scope-dependent) ──
  int get activeTasks => throw _privateConstructorUsedError;
  int get completedTasks => throw _privateConstructorUsedError;
  int get completedTasksToday => throw _privateConstructorUsedError;
  int get waitingReviews => throw _privateConstructorUsedError;
  int get rejectedTasks => throw _privateConstructorUsedError;
  int get rejectedTasksToday =>
      throw _privateConstructorUsedError; // ── Employee (own data) ──
  int get assignedTasks => throw _privateConstructorUsedError;
  int get pendingTasks => throw _privateConstructorUsedError;

  /// Name of the employee's current assigned shift (e.g. `morning`), if any.
  String? get currentShiftName => throw _privateConstructorUsedError;

  /// Create a copy of StatisticsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatisticsEntityCopyWith<StatisticsEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatisticsEntityCopyWith<$Res> {
  factory $StatisticsEntityCopyWith(
    StatisticsEntity value,
    $Res Function(StatisticsEntity) then,
  ) = _$StatisticsEntityCopyWithImpl<$Res, StatisticsEntity>;
  @useResult
  $Res call({
    int totalBranches,
    int totalManagers,
    int totalEmployees,
    int pendingApprovals,
    int branchesWithoutManagers,
    int employeesInBranch,
    int morningShiftEmployees,
    int nightShiftEmployees,
    int dailyTasks,
    int specialTasks,
    int activeTasks,
    int completedTasks,
    int completedTasksToday,
    int waitingReviews,
    int rejectedTasks,
    int rejectedTasksToday,
    int assignedTasks,
    int pendingTasks,
    String? currentShiftName,
  });
}

/// @nodoc
class _$StatisticsEntityCopyWithImpl<$Res, $Val extends StatisticsEntity>
    implements $StatisticsEntityCopyWith<$Res> {
  _$StatisticsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatisticsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalBranches = null,
    Object? totalManagers = null,
    Object? totalEmployees = null,
    Object? pendingApprovals = null,
    Object? branchesWithoutManagers = null,
    Object? employeesInBranch = null,
    Object? morningShiftEmployees = null,
    Object? nightShiftEmployees = null,
    Object? dailyTasks = null,
    Object? specialTasks = null,
    Object? activeTasks = null,
    Object? completedTasks = null,
    Object? completedTasksToday = null,
    Object? waitingReviews = null,
    Object? rejectedTasks = null,
    Object? rejectedTasksToday = null,
    Object? assignedTasks = null,
    Object? pendingTasks = null,
    Object? currentShiftName = freezed,
  }) {
    return _then(
      _value.copyWith(
            totalBranches: null == totalBranches
                ? _value.totalBranches
                : totalBranches // ignore: cast_nullable_to_non_nullable
                      as int,
            totalManagers: null == totalManagers
                ? _value.totalManagers
                : totalManagers // ignore: cast_nullable_to_non_nullable
                      as int,
            totalEmployees: null == totalEmployees
                ? _value.totalEmployees
                : totalEmployees // ignore: cast_nullable_to_non_nullable
                      as int,
            pendingApprovals: null == pendingApprovals
                ? _value.pendingApprovals
                : pendingApprovals // ignore: cast_nullable_to_non_nullable
                      as int,
            branchesWithoutManagers: null == branchesWithoutManagers
                ? _value.branchesWithoutManagers
                : branchesWithoutManagers // ignore: cast_nullable_to_non_nullable
                      as int,
            employeesInBranch: null == employeesInBranch
                ? _value.employeesInBranch
                : employeesInBranch // ignore: cast_nullable_to_non_nullable
                      as int,
            morningShiftEmployees: null == morningShiftEmployees
                ? _value.morningShiftEmployees
                : morningShiftEmployees // ignore: cast_nullable_to_non_nullable
                      as int,
            nightShiftEmployees: null == nightShiftEmployees
                ? _value.nightShiftEmployees
                : nightShiftEmployees // ignore: cast_nullable_to_non_nullable
                      as int,
            dailyTasks: null == dailyTasks
                ? _value.dailyTasks
                : dailyTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            specialTasks: null == specialTasks
                ? _value.specialTasks
                : specialTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            activeTasks: null == activeTasks
                ? _value.activeTasks
                : activeTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            completedTasks: null == completedTasks
                ? _value.completedTasks
                : completedTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            completedTasksToday: null == completedTasksToday
                ? _value.completedTasksToday
                : completedTasksToday // ignore: cast_nullable_to_non_nullable
                      as int,
            waitingReviews: null == waitingReviews
                ? _value.waitingReviews
                : waitingReviews // ignore: cast_nullable_to_non_nullable
                      as int,
            rejectedTasks: null == rejectedTasks
                ? _value.rejectedTasks
                : rejectedTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            rejectedTasksToday: null == rejectedTasksToday
                ? _value.rejectedTasksToday
                : rejectedTasksToday // ignore: cast_nullable_to_non_nullable
                      as int,
            assignedTasks: null == assignedTasks
                ? _value.assignedTasks
                : assignedTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            pendingTasks: null == pendingTasks
                ? _value.pendingTasks
                : pendingTasks // ignore: cast_nullable_to_non_nullable
                      as int,
            currentShiftName: freezed == currentShiftName
                ? _value.currentShiftName
                : currentShiftName // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatisticsEntityImplCopyWith<$Res>
    implements $StatisticsEntityCopyWith<$Res> {
  factory _$$StatisticsEntityImplCopyWith(
    _$StatisticsEntityImpl value,
    $Res Function(_$StatisticsEntityImpl) then,
  ) = __$$StatisticsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalBranches,
    int totalManagers,
    int totalEmployees,
    int pendingApprovals,
    int branchesWithoutManagers,
    int employeesInBranch,
    int morningShiftEmployees,
    int nightShiftEmployees,
    int dailyTasks,
    int specialTasks,
    int activeTasks,
    int completedTasks,
    int completedTasksToday,
    int waitingReviews,
    int rejectedTasks,
    int rejectedTasksToday,
    int assignedTasks,
    int pendingTasks,
    String? currentShiftName,
  });
}

/// @nodoc
class __$$StatisticsEntityImplCopyWithImpl<$Res>
    extends _$StatisticsEntityCopyWithImpl<$Res, _$StatisticsEntityImpl>
    implements _$$StatisticsEntityImplCopyWith<$Res> {
  __$$StatisticsEntityImplCopyWithImpl(
    _$StatisticsEntityImpl _value,
    $Res Function(_$StatisticsEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StatisticsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalBranches = null,
    Object? totalManagers = null,
    Object? totalEmployees = null,
    Object? pendingApprovals = null,
    Object? branchesWithoutManagers = null,
    Object? employeesInBranch = null,
    Object? morningShiftEmployees = null,
    Object? nightShiftEmployees = null,
    Object? dailyTasks = null,
    Object? specialTasks = null,
    Object? activeTasks = null,
    Object? completedTasks = null,
    Object? completedTasksToday = null,
    Object? waitingReviews = null,
    Object? rejectedTasks = null,
    Object? rejectedTasksToday = null,
    Object? assignedTasks = null,
    Object? pendingTasks = null,
    Object? currentShiftName = freezed,
  }) {
    return _then(
      _$StatisticsEntityImpl(
        totalBranches: null == totalBranches
            ? _value.totalBranches
            : totalBranches // ignore: cast_nullable_to_non_nullable
                  as int,
        totalManagers: null == totalManagers
            ? _value.totalManagers
            : totalManagers // ignore: cast_nullable_to_non_nullable
                  as int,
        totalEmployees: null == totalEmployees
            ? _value.totalEmployees
            : totalEmployees // ignore: cast_nullable_to_non_nullable
                  as int,
        pendingApprovals: null == pendingApprovals
            ? _value.pendingApprovals
            : pendingApprovals // ignore: cast_nullable_to_non_nullable
                  as int,
        branchesWithoutManagers: null == branchesWithoutManagers
            ? _value.branchesWithoutManagers
            : branchesWithoutManagers // ignore: cast_nullable_to_non_nullable
                  as int,
        employeesInBranch: null == employeesInBranch
            ? _value.employeesInBranch
            : employeesInBranch // ignore: cast_nullable_to_non_nullable
                  as int,
        morningShiftEmployees: null == morningShiftEmployees
            ? _value.morningShiftEmployees
            : morningShiftEmployees // ignore: cast_nullable_to_non_nullable
                  as int,
        nightShiftEmployees: null == nightShiftEmployees
            ? _value.nightShiftEmployees
            : nightShiftEmployees // ignore: cast_nullable_to_non_nullable
                  as int,
        dailyTasks: null == dailyTasks
            ? _value.dailyTasks
            : dailyTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        specialTasks: null == specialTasks
            ? _value.specialTasks
            : specialTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        activeTasks: null == activeTasks
            ? _value.activeTasks
            : activeTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        completedTasks: null == completedTasks
            ? _value.completedTasks
            : completedTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        completedTasksToday: null == completedTasksToday
            ? _value.completedTasksToday
            : completedTasksToday // ignore: cast_nullable_to_non_nullable
                  as int,
        waitingReviews: null == waitingReviews
            ? _value.waitingReviews
            : waitingReviews // ignore: cast_nullable_to_non_nullable
                  as int,
        rejectedTasks: null == rejectedTasks
            ? _value.rejectedTasks
            : rejectedTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        rejectedTasksToday: null == rejectedTasksToday
            ? _value.rejectedTasksToday
            : rejectedTasksToday // ignore: cast_nullable_to_non_nullable
                  as int,
        assignedTasks: null == assignedTasks
            ? _value.assignedTasks
            : assignedTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        pendingTasks: null == pendingTasks
            ? _value.pendingTasks
            : pendingTasks // ignore: cast_nullable_to_non_nullable
                  as int,
        currentShiftName: freezed == currentShiftName
            ? _value.currentShiftName
            : currentShiftName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$StatisticsEntityImpl implements _StatisticsEntity {
  const _$StatisticsEntityImpl({
    this.totalBranches = 0,
    this.totalManagers = 0,
    this.totalEmployees = 0,
    this.pendingApprovals = 0,
    this.branchesWithoutManagers = 0,
    this.employeesInBranch = 0,
    this.morningShiftEmployees = 0,
    this.nightShiftEmployees = 0,
    this.dailyTasks = 0,
    this.specialTasks = 0,
    this.activeTasks = 0,
    this.completedTasks = 0,
    this.completedTasksToday = 0,
    this.waitingReviews = 0,
    this.rejectedTasks = 0,
    this.rejectedTasksToday = 0,
    this.assignedTasks = 0,
    this.pendingTasks = 0,
    this.currentShiftName,
  });

  // ── Admin (global) ──
  @override
  @JsonKey()
  final int totalBranches;
  @override
  @JsonKey()
  final int totalManagers;
  @override
  @JsonKey()
  final int totalEmployees;
  @override
  @JsonKey()
  final int pendingApprovals;
  @override
  @JsonKey()
  final int branchesWithoutManagers;
  // ── Manager (own branch) ──
  @override
  @JsonKey()
  final int employeesInBranch;
  @override
  @JsonKey()
  final int morningShiftEmployees;
  @override
  @JsonKey()
  final int nightShiftEmployees;
  @override
  @JsonKey()
  final int dailyTasks;
  @override
  @JsonKey()
  final int specialTasks;
  // ── Tasks (shared, scope-dependent) ──
  @override
  @JsonKey()
  final int activeTasks;
  @override
  @JsonKey()
  final int completedTasks;
  @override
  @JsonKey()
  final int completedTasksToday;
  @override
  @JsonKey()
  final int waitingReviews;
  @override
  @JsonKey()
  final int rejectedTasks;
  @override
  @JsonKey()
  final int rejectedTasksToday;
  // ── Employee (own data) ──
  @override
  @JsonKey()
  final int assignedTasks;
  @override
  @JsonKey()
  final int pendingTasks;

  /// Name of the employee's current assigned shift (e.g. `morning`), if any.
  @override
  final String? currentShiftName;

  @override
  String toString() {
    return 'StatisticsEntity(totalBranches: $totalBranches, totalManagers: $totalManagers, totalEmployees: $totalEmployees, pendingApprovals: $pendingApprovals, branchesWithoutManagers: $branchesWithoutManagers, employeesInBranch: $employeesInBranch, morningShiftEmployees: $morningShiftEmployees, nightShiftEmployees: $nightShiftEmployees, dailyTasks: $dailyTasks, specialTasks: $specialTasks, activeTasks: $activeTasks, completedTasks: $completedTasks, completedTasksToday: $completedTasksToday, waitingReviews: $waitingReviews, rejectedTasks: $rejectedTasks, rejectedTasksToday: $rejectedTasksToday, assignedTasks: $assignedTasks, pendingTasks: $pendingTasks, currentShiftName: $currentShiftName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatisticsEntityImpl &&
            (identical(other.totalBranches, totalBranches) ||
                other.totalBranches == totalBranches) &&
            (identical(other.totalManagers, totalManagers) ||
                other.totalManagers == totalManagers) &&
            (identical(other.totalEmployees, totalEmployees) ||
                other.totalEmployees == totalEmployees) &&
            (identical(other.pendingApprovals, pendingApprovals) ||
                other.pendingApprovals == pendingApprovals) &&
            (identical(
                  other.branchesWithoutManagers,
                  branchesWithoutManagers,
                ) ||
                other.branchesWithoutManagers == branchesWithoutManagers) &&
            (identical(other.employeesInBranch, employeesInBranch) ||
                other.employeesInBranch == employeesInBranch) &&
            (identical(other.morningShiftEmployees, morningShiftEmployees) ||
                other.morningShiftEmployees == morningShiftEmployees) &&
            (identical(other.nightShiftEmployees, nightShiftEmployees) ||
                other.nightShiftEmployees == nightShiftEmployees) &&
            (identical(other.dailyTasks, dailyTasks) ||
                other.dailyTasks == dailyTasks) &&
            (identical(other.specialTasks, specialTasks) ||
                other.specialTasks == specialTasks) &&
            (identical(other.activeTasks, activeTasks) ||
                other.activeTasks == activeTasks) &&
            (identical(other.completedTasks, completedTasks) ||
                other.completedTasks == completedTasks) &&
            (identical(other.completedTasksToday, completedTasksToday) ||
                other.completedTasksToday == completedTasksToday) &&
            (identical(other.waitingReviews, waitingReviews) ||
                other.waitingReviews == waitingReviews) &&
            (identical(other.rejectedTasks, rejectedTasks) ||
                other.rejectedTasks == rejectedTasks) &&
            (identical(other.rejectedTasksToday, rejectedTasksToday) ||
                other.rejectedTasksToday == rejectedTasksToday) &&
            (identical(other.assignedTasks, assignedTasks) ||
                other.assignedTasks == assignedTasks) &&
            (identical(other.pendingTasks, pendingTasks) ||
                other.pendingTasks == pendingTasks) &&
            (identical(other.currentShiftName, currentShiftName) ||
                other.currentShiftName == currentShiftName));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    totalBranches,
    totalManagers,
    totalEmployees,
    pendingApprovals,
    branchesWithoutManagers,
    employeesInBranch,
    morningShiftEmployees,
    nightShiftEmployees,
    dailyTasks,
    specialTasks,
    activeTasks,
    completedTasks,
    completedTasksToday,
    waitingReviews,
    rejectedTasks,
    rejectedTasksToday,
    assignedTasks,
    pendingTasks,
    currentShiftName,
  ]);

  /// Create a copy of StatisticsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatisticsEntityImplCopyWith<_$StatisticsEntityImpl> get copyWith =>
      __$$StatisticsEntityImplCopyWithImpl<_$StatisticsEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _StatisticsEntity implements StatisticsEntity {
  const factory _StatisticsEntity({
    final int totalBranches,
    final int totalManagers,
    final int totalEmployees,
    final int pendingApprovals,
    final int branchesWithoutManagers,
    final int employeesInBranch,
    final int morningShiftEmployees,
    final int nightShiftEmployees,
    final int dailyTasks,
    final int specialTasks,
    final int activeTasks,
    final int completedTasks,
    final int completedTasksToday,
    final int waitingReviews,
    final int rejectedTasks,
    final int rejectedTasksToday,
    final int assignedTasks,
    final int pendingTasks,
    final String? currentShiftName,
  }) = _$StatisticsEntityImpl;

  // ── Admin (global) ──
  @override
  int get totalBranches;
  @override
  int get totalManagers;
  @override
  int get totalEmployees;
  @override
  int get pendingApprovals;
  @override
  int get branchesWithoutManagers; // ── Manager (own branch) ──
  @override
  int get employeesInBranch;
  @override
  int get morningShiftEmployees;
  @override
  int get nightShiftEmployees;
  @override
  int get dailyTasks;
  @override
  int get specialTasks; // ── Tasks (shared, scope-dependent) ──
  @override
  int get activeTasks;
  @override
  int get completedTasks;
  @override
  int get completedTasksToday;
  @override
  int get waitingReviews;
  @override
  int get rejectedTasks;
  @override
  int get rejectedTasksToday; // ── Employee (own data) ──
  @override
  int get assignedTasks;
  @override
  int get pendingTasks;

  /// Name of the employee's current assigned shift (e.g. `morning`), if any.
  @override
  String? get currentShiftName;

  /// Create a copy of StatisticsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatisticsEntityImplCopyWith<_$StatisticsEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
