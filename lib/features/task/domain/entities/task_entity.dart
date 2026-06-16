import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';

part 'task_entity.freezed.dart';

/// A unit of work in FBRO (Phase 3) — the core operations workflow: a
/// manager/admin creates and assigns a task, one or more employees execute it
/// (start → complete, with optional notes + proof image), and a manager/admin
/// reviews it (approve / reject).
///
/// A task is branch-scoped via [branchId] and may be tied to an
/// [assignedShiftId]. It supports **multiple assignees** ([assigneeIds], Phase 9
/// — replaces the former single `assignedEmployeeId`) and an optional
/// **[checklist]** generated from a checklist template. Access is enforced
/// server-side in `firestore.rules` (admin: all branches · manager: own branch ·
/// employee: tasks they're assigned to).
@freezed
class TaskEntity with _$TaskEntity {
  const TaskEntity._();

  const factory TaskEntity({
    required String id,
    required String title,
    String? description,
    @Default(TaskType.daily) TaskType type,
    @Default(TaskStatus.pending) TaskStatus status,
    @Default(TaskPriority.normal) TaskPriority priority,
    /// Owning branch (admin: any · manager: own branch).
    String? branchId,
    /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
    /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
    @Default(<String>[]) List<String> assigneeIds,
    /// Checklist the employee must work through (generated from a template).
    @Default(<ChecklistItem>[]) List<ChecklistItem> checklist,
    /// uid of the manager/admin who created the task.
    String? createdBy,
    /// Optional shift this task belongs to (references `shifts/{shiftId}`).
    String? assignedShiftId,
    DateTime? deadline,
    /// Free-text notes added by the executing employee.
    String? notes,
    /// Download URL of the proof image the employee uploads on completion.
    String? proofImageUrl,
    // ─── Review audit (Phase 4 — lightweight, not a full history) ───
    /// uid of the manager/admin who approved the task, + when.
    String? approvedBy,
    DateTime? approvedAt,
    /// uid of the manager/admin who rejected the task, + when.
    String? rejectedBy,
    DateTime? rejectedAt,
    /// Reviewer's note left on approve/reject.
    String? reviewNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TaskEntity;

  /// Whether anyone is assigned.
  bool get isAssigned => assigneeIds.isNotEmpty;

  // ─── Checklist progress (Phase 9) ──────────────────────────────
  bool get hasChecklist => checklist.isNotEmpty;
  int get checklistTotal => checklist.length;
  int get checklistDone => checklist.where((c) => c.completed).length;

  /// 0.0–1.0 completion (1.0 when there is no checklist).
  double get checklistProgress =>
      checklist.isEmpty ? 1 : checklistDone / checklistTotal;

  /// True when every **required** checklist item is completed — the gate for
  /// marking the task completed.
  bool get requiredChecklistComplete =>
      checklist.where((c) => c.isRequired).every((c) => c.completed);
}
