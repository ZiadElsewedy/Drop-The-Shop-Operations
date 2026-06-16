import 'dart:io';
import 'package:fbro/core/enums/task_status.dart';
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

  /// Assigns an employee (and optionally a shift) to the task; pass null to
  /// unassign.
  Future<void> assignTask({
    required String taskId,
    required String? employeeId,
    String? assignedShiftId,
  });

  /// Moves the task to [status] (employee start/complete/submit). Approve/reject
  /// go through [reviewTask] so the audit fields are written together.
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
  });

  /// Reviews the task: sets the terminal status (approved/rejected) together with
  /// the audit fields (approvedBy/approvedAt or rejectedBy/rejectedAt) and an
  /// optional [reviewNotes]. Manager (own branch) / admin only.
  Future<void> reviewTask({
    required String taskId,
    required bool approved,
    required String reviewerId,
    String? reviewNotes,
  });

  /// Uploads a proof image to Storage for the task and returns its download URL.
  Future<String> uploadProof(String taskId, File file);

  // ─── Task templates (reusable blueprints) ──────────────────────
  /// All task templates (manager/admin). Branch scoping is applied by the cubit.
  Future<List<TaskTemplateEntity>> getTemplates();

  /// Creates a template and returns it with its generated id.
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template);

  /// Deletes a template.
  Future<void> deleteTemplate(String templateId);
}
