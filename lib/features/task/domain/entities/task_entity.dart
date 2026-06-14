import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/task_priority.dart';

part 'task_entity.freezed.dart';

/// A unit of work in FBRO (Phase 3) — the core operations workflow: a
/// manager/admin creates and assigns a task, an employee executes it (start →
/// complete, with optional notes + proof image), and a manager/admin reviews it
/// (approve / reject).
///
/// A task is branch-scoped via [branchId] and may be tied to a [assignedShiftId]
/// and a single [assignedEmployeeId]. Access is enforced server-side in
/// `firestore.rules` (admin: all branches · manager: own branch · employee: own
/// assigned tasks).
@freezed
class TaskEntity with _$TaskEntity {
  const factory TaskEntity({
    required String id,
    required String title,
    String? description,
    @Default(TaskType.daily) TaskType type,
    @Default(TaskStatus.pending) TaskStatus status,
    @Default(TaskPriority.normal) TaskPriority priority,
    /// Owning branch (admin: any · manager: own branch).
    String? branchId,
    /// The single employee assigned to execute the task; null while unassigned.
    String? assignedEmployeeId,
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
}
