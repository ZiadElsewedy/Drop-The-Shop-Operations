import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/enums/task_priority.dart';

part 'task_template_entity.freezed.dart';

/// A reusable task blueprint — e.g. "Open Shop", "Close Shop", "Morning
/// Checklist", "Night Checklist". A manager/admin instantiates it into a real
/// [TaskEntity] from the New Task flow, so recurring daily work isn't retyped
/// each shift.
///
/// A template carries only the task's *content* (title / description / type /
/// priority) — never an assignment or a status; those are decided when a task
/// is created from it. It is branch-scoped via [branchId] exactly like a task
/// (admin: any/global · manager: own branch); access is enforced server-side in
/// `firestore.rules` (`task_templates/{id}`).
@freezed
class TaskTemplateEntity with _$TaskTemplateEntity {
  const factory TaskTemplateEntity({
    required String id,
    required String title,
    String? description,
    @Default(TaskType.daily) TaskType type,
    @Default(TaskPriority.normal) TaskPriority priority,

    /// Owning branch. Empty/null = a GLOBAL template (admin-made), available to
    /// every branch; otherwise scoped to that branch's managers/admins.
    String? branchId,

    /// uid of the manager/admin who created the template.
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TaskTemplateEntity;
}
