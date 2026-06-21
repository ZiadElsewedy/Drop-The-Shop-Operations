import 'dart:io';
import 'package:fbro/core/enums/attachment_type.dart';
import 'package:fbro/features/task/domain/entities/task_attachment.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';

/// Contract for task data access (Phase 3 foundation). The branch/role access
/// model is enforced server-side by `firestore.rules` (admin: all branches;
/// manager: own branch; employee: own assigned tasks, limited writes); these
/// methods are the client-side surface the task UI (next phase) builds on.
abstract class TaskRepository {
  /// All tasks — admin only (the rules reject a non-admin collection read).
  Future<List<TaskEntity>> getAllTasks();

  /// Tasks in a single branch — admin or that branch's manager.
  Future<List<TaskEntity>> getTasksByBranch(String branchId);

  /// Tasks assigned to [employeeId] (the employee's own view).
  Future<List<TaskEntity>> getEmployeeTasks(String employeeId);

  /// Real-time task lists (admin: all · manager: branch · employee: own) — emit
  /// on every change so assignments/updates appear immediately.
  Stream<List<TaskEntity>> watchAllTasks();
  Stream<List<TaskEntity>> watchTasksByBranch(String branchId);
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId);

  /// A single task by id, or null if it doesn't exist.
  Future<TaskEntity?> getTask(String taskId);

  /// Creates a task and returns it with its generated id.
  Future<TaskEntity> createTask(TaskEntity task);

  /// Updates an existing task (manager/admin full edit; employee limited fields).
  Future<void> updateTask(TaskEntity task);

  /// Deletes a task (manager/admin).
  Future<void> deleteTask(String taskId);

  /// Sets the task's assignees (Phase 9 — multi-assignee) and optionally a
  /// shift. Pass an empty list to unassign.
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  });

  /// Uploads one media file (image / video) to Storage under the task's
  /// `attachments/` folder and returns the resolved [TaskAttachment]. Each call
  /// creates a uniquely-named object (no overwrite).
  ///
  /// Status transitions (start / complete+submit / approve / reject) all flow
  /// through [updateTask] as a single write that also appends the activity-log
  /// entry (with its attachments), so there is intentionally no separate
  /// status/review method here.
  Future<TaskAttachment> uploadAttachment({
    required String taskId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  });

  // ─── Task templates (reusable blueprints) ──────────────────────
  /// All task templates (manager/admin). Branch scoping is applied by the cubit.
  Future<List<TaskTemplateEntity>> getTemplates();

  /// Creates a template and returns it with its generated id.
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template);

  /// Deletes a template.
  Future<void> deleteTemplate(String templateId);
}
