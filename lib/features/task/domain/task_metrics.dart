/// Pure task-metric derivations for the dashboard "Needs Attention" tiles and
/// the "Today" stat strip (DROP Design System V2). No Flutter, no Firestore — it
/// derives the operational counts straight from the already-in-memory
/// `TaskCubit` stream (zero new reads), so each figure is unit-testable and
/// cannot drift from the live task list. Reuses the canonical predicates in
/// [isTaskOverdue] / [isTaskInActiveWindow] so a task counts the same way here as
/// it does in the feed.
library;

import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/task/domain/active_window.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';

/// Open tasks (pending / started / rejected) past their deadline — the shared
/// "overdue" definition (terminal states are never overdue).
int overdueCount(List<TaskEntity> tasks, DateTime now) =>
    tasks.where((t) => isTaskOverdue(t, now)).length;

/// Tasks submitted and awaiting a manager/admin review decision.
int reviewCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.waitingReview).length;

/// Tasks an employee is actively executing right now.
int runningNowCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.started).length;

/// Active individual/team tasks with **no owner** — they can't progress until
/// someone is assigned. Shift tasks target a shift (never "unassigned"), and
/// already-finished work is excluded via the active window.
int unassignedCount(List<TaskEntity> tasks, DateTime now) => tasks
    .where((t) =>
        isTaskInActiveWindow(t, now) &&
        t.assignmentType != TaskAssignmentType.shift &&
        t.assigneeIds.isEmpty &&
        t.status != TaskStatus.approved)
    .length;

/// Tasks sent back to the employee (rejected / rework) and still outstanding.
int rejectedCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.rejected).length;

/// Approval rate as a whole-number percentage (0–100) over decided work, or
/// `null` when nothing has been decided yet (so the UI can show "—" instead of a
/// misleading 0%). [approved] + [rejected] is the decided total.
int? approvalRatePct({required int approved, required int rejected}) {
  final decided = approved + rejected;
  if (decided <= 0) return null;
  return ((approved / decided) * 100).round();
}
