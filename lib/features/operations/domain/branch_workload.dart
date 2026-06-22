import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/operations/domain/branch_summary.dart';
import 'package:fbro/features/operations/domain/employee_workload.dart';
import 'package:fbro/features/operations/domain/shift_filter.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';

/// The fully-derived state of the Branch Operations cockpit for one shift lens:
/// the header [summary] plus the [employees] cards, already sorted
/// overload-first. Produced by [computeBranchWorkload].
class BranchWorkload {
  const BranchWorkload({required this.summary, required this.employees});

  final BranchSummary summary;
  final List<EmployeeWorkload> employees;

  static const empty =
      BranchWorkload(summary: BranchSummary(), employees: <EmployeeWorkload>[]);
}

/// Joins a branch's [tasks] (the live `watchTasksByBranch` stream) with its
/// [employees] (`getUsersByBranch`) and today's [schedule] roster into the
/// Branch Operations view model, under the given shift [filter].
///
/// Pure and deterministic — [day] and [now] are injectable so the derivation is
/// unit-testable without a clock (mirrors `computeEmployeeMetrics`). Everything
/// — summary numbers, per-employee counts, sort order — is recomputed here, so
/// flipping the shift filter is a re-derive, never a refetch.
BranchWorkload computeBranchWorkload({
  required List<UserEntity> employees,
  required List<TaskEntity> tasks,
  WeeklyScheduleEntity? schedule,
  ShiftFilter filter = ShiftFilter.all,
  ScheduleDay? day,
  DateTime? now,
}) {
  final today = day ?? ScheduleDay.today();
  final clock = now ?? DateTime.now();

  List<ScheduleShift> shiftsOf(UserEntity u) =>
      schedule?.shiftsFor(u.uid, today) ?? const [];

  // Apply the shift lens to both axes.
  final visibleTasks =
      tasks.where((t) => filter.matchesTask(t.shift)).toList();
  final visibleEmployees =
      employees.where((u) => filter.matchesEmployee(shiftsOf(u))).toList();

  // Per-employee cards.
  final workloads = <EmployeeWorkload>[];
  for (final u in visibleEmployees) {
    final mine =
        visibleTasks.where((t) => t.assigneeIds.contains(u.uid)).toList();
    var active = 0, overdue = 0, submitted = 0, completedToday = 0;
    for (final t in mine) {
      if (_isActive(t.status)) {
        active++;
        if (_isOverdue(t, clock)) overdue++;
      } else if (_isSubmitted(t.status)) {
        submitted++;
      } else if (t.status == TaskStatus.approved &&
          t.approvedAt != null &&
          _sameDay(t.approvedAt!, clock)) {
        completedToday++;
      }
    }
    workloads.add(EmployeeWorkload(
      user: u,
      shiftsToday: shiftsOf(u),
      active: active,
      overdue: overdue,
      submitted: submitted,
      completedToday: completedToday,
      currentTask: _currentTask(mine),
    ));
  }

  // Overload-first: most overdue, then most active, then name — so the manager
  // sees who's drowning by scan order alone.
  workloads.sort((a, b) {
    final byOverdue = b.overdue.compareTo(a.overdue);
    if (byOverdue != 0) return byOverdue;
    final byActive = b.active.compareTo(a.active);
    if (byActive != 0) return byActive;
    return _name(a.user).toLowerCase().compareTo(_name(b.user).toLowerCase());
  });

  // Branch summary over the same visible scope.
  var activeTasks = 0, overdueTasks = 0, pendingReviews = 0;
  for (final t in visibleTasks) {
    if (_isActive(t.status)) {
      activeTasks++;
      if (_isOverdue(t, clock)) overdueTasks++;
    } else if (_isSubmitted(t.status)) {
      pendingReviews++;
    }
  }

  return BranchWorkload(
    summary: BranchSummary(
      activeTasks: activeTasks,
      overdueTasks: overdueTasks,
      pendingReviews: pendingReviews,
      staffActive: visibleEmployees.where((u) => shiftsOf(u).isNotEmpty).length,
    ),
    employees: workloads,
  );
}

/// Open, employee-actionable work.
bool _isActive(TaskStatus s) =>
    s == TaskStatus.pending ||
    s == TaskStatus.started ||
    s == TaskStatus.rejected;

/// Done by the employee, awaiting a review decision.
bool _isSubmitted(TaskStatus s) =>
    s == TaskStatus.completed || s == TaskStatus.waitingReview;

/// Active work whose deadline has passed.
bool _isOverdue(TaskEntity t, DateTime clock) =>
    t.deadline != null && t.deadline!.isBefore(clock);

/// The employee's "current" task: the started one (else next-up rework, else
/// next pending), tie-broken by soonest deadline. Null when nothing is open.
TaskEntity? _currentTask(List<TaskEntity> mine) {
  int rank(TaskStatus s) => switch (s) {
        TaskStatus.started => 0,
        TaskStatus.rejected => 1,
        TaskStatus.pending => 2,
        _ => 3,
      };
  final open = mine.where((t) => _isActive(t.status)).toList()
    ..sort((a, b) {
      final byRank = rank(a.status).compareTo(rank(b.status));
      if (byRank != 0) return byRank;
      final ad = a.deadline, bd = b.deadline;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
  return open.isEmpty ? null : open.first;
}

String _name(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty)
        ? u.displayName!
        : u.email;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
