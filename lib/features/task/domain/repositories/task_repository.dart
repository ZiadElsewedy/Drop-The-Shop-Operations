import 'dart:io';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/media/media_upload_service.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';

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

  /// Real-time shift-assigned tasks for one (branch, shift) — the other half of
  /// an employee's task stream when they're rostered on [shift] today (Shift
  /// Assignment feature). Merged client-side with [watchEmployeeTasks] by
  /// `TaskCubit`; `assigneeIds` stays empty on these, so they'd never appear in
  /// [watchEmployeeTasks] alone.
  Stream<List<TaskEntity>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  });

  /// A single task by id, or null if it doesn't exist.
  Future<TaskEntity?> getTask(String taskId);

  /// Creates a task and returns it with its generated id.
  Future<TaskEntity> createTask(TaskEntity task);

  /// Creates [task] at its own `task.id` (a caller-assigned **deterministic**
  /// id, not auto-generated) — a no-op returning null if that id already
  /// exists. Used to materialize a recurring shift-task's "today" instance
  /// client-side with the exact same deterministic id
  /// (`rt_{templateId}_{yyyy-MM-dd}`) the `generateShiftTaskInstances` Cloud
  /// Function uses, so the two can never double-create the same day's instance.
  Future<TaskEntity?> createTaskWithId(TaskEntity task);

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
    UploadCanceller? canceller,
    void Function(int transferred, int total)? onProgress,
  });

  // ─── Task templates (reusable blueprints) ──────────────────────
  /// All task templates (manager/admin). Branch scoping is applied by the cubit.
  /// Cached in memory for a short TTL; [forceRefresh] bypasses it, and any
  /// template write invalidates it.
  Future<List<TaskTemplateEntity>> getTemplates({bool forceRefresh = false});

  /// Creates a template and returns it with its generated id.
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template);

  /// Deletes a template.
  Future<void> deleteTemplate(String templateId);

  // ─── Recurring shift-task templates (Shift Assignment feature) ─
  /// All recurring shift-task templates for [branchId] (manager/admin).
  Future<List<RecurringTaskTemplateEntity>> getRecurringTemplates(
      String branchId);

  /// Creates a recurring shift-task template and returns it with its
  /// generated id.
  Future<RecurringTaskTemplateEntity> createRecurringTemplate(
      RecurringTaskTemplateEntity template);

  /// Updates a template (used to pause/resume via `active`).
  Future<void> updateRecurringTemplate(RecurringTaskTemplateEntity template);

  /// Deletes a template. Already-generated instances are untouched.
  Future<void> deleteRecurringTemplate(String templateId);
}
