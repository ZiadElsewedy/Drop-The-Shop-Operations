import 'package:freezed_annotation/freezed_annotation.dart';

part 'statistics_entity.freezed.dart';

/// Operational statistics for a DROP THE SHOP dashboard (Phase 6). A single bag
/// of counts populated per role — admin (global), manager (own branch) and
/// employee (own data) each read the fields relevant to their dashboard. Counts
/// are computed from branch-scoped Firestore queries (no analytics engine).
@freezed
class StatisticsEntity with _$StatisticsEntity {
  const factory StatisticsEntity({
    // ── Admin (global) ──
    @Default(0) int totalBranches,
    @Default(0) int totalManagers,
    @Default(0) int totalEmployees,
    @Default(0) int pendingApprovals,
    @Default(0) int branchesWithoutManagers,
    // ── Manager (own branch) ──
    @Default(0) int employeesInBranch,
    @Default(0) int morningShiftEmployees,
    @Default(0) int nightShiftEmployees,
    @Default(0) int dailyTasks,
    @Default(0) int specialTasks,
    // ── Tasks (shared, scope-dependent) ──
    @Default(0) int activeTasks,
    @Default(0) int completedTasks,
    @Default(0) int completedTasksToday,
    @Default(0) int waitingReviews,
    @Default(0) int rejectedTasks,
    @Default(0) int rejectedTasksToday,
    // ── Employee (own data) ──
    @Default(0) int assignedTasks,
    @Default(0) int pendingTasks,
    /// Name of the employee's current assigned shift (e.g. `morning`), if any.
    String? currentShiftName,
  }) = _StatisticsEntity;
}
