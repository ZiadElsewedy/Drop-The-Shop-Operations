import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';
import 'package:fbro/core/enums/attachment_type.dart';
import 'package:fbro/features/task/domain/entities/activity_entry.dart';
import 'package:fbro/features/task/domain/entities/checklist_item.dart';
import 'package:fbro/features/task/domain/entities/recurrence_config.dart';
import 'package:fbro/features/task/domain/entities/task_attachment.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';
import 'package:fbro/features/task/domain/usecases/assign_task.dart';
import 'package:fbro/features/task/domain/usecases/create_task.dart';
import 'package:fbro/features/task/domain/usecases/delete_task.dart';
import 'package:fbro/features/task/domain/usecases/update_task.dart';
import 'package:fbro/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:fbro/features/task/presentation/submission_progress.dart';
import 'task_state.dart';

/// A media file the employee has picked but not yet uploaded — the input to
/// [TaskCubit.completeAndSubmit]. The cubit uploads each and turns it into a
/// [TaskAttachment] on the submission event. [durationMs] is the captured video
/// length (best-effort; null for images).
class PickedAttachment {
  const PickedAttachment(this.file, this.type, {this.durationMs});
  final File file;
  final AttachmentType type;
  final int? durationMs;
}

/// Drives the task workflow for all three roles. The list loaded depends on the
/// signed-in user's role (admin: all · manager: own branch · employee: tasks
/// they're assigned to) and is **realtime** — a Firestore snapshot stream.
///
/// Phase 9+: tasks support **multiple assignees**, an optional **checklist**,
/// **recurring schedules** (auto-creates the next instance on approve), and an
/// **activity timeline** (one entry per status transition). The cubit resolves
/// assignee uids → [UserEntity] (the [directory]) so cards show real names.
class TaskCubit extends Cubit<TaskState> {
  final TaskRepository _repository;
  final BranchRepository _branchRepository;
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final AssignTask _assignTask;
  final UploadTaskAttachment _uploadTaskAttachment;
  final GetUsersByBranch _getUsersByBranch;
  final NotifyTaskEvent _notifyTaskEvent;

  UserEntity? _user;
  StreamSubscription<List<TaskEntity>>? _sub;
  bool _mutating = false;
  // Submission lives on the cubit (not a widget) so the whole screen reacts and
  // it survives rebuilds; carried on every `loaded` emit (incl. the stream).
  bool _submitting = false;
  SubmissionProgress? _submissionProgress;
  final Map<String, UserEntity> _directory = {};
  final Set<String> _fetchedBranches = {};
  final Map<String, String> _branchNames = {};

  Map<String, UserEntity> get directory => Map.unmodifiable(_directory);

  /// branchId → branch name, so screens (e.g. the review header) can show which
  /// branch a task belongs to. Populated once per session in [load].
  Map<String, String> get branchNames => Map.unmodifiable(_branchNames);

  TaskCubit({
    required this._repository,
    required this._branchRepository,
    required this._createTask,
    required this._updateTask,
    required this._deleteTask,
    required this._assignTask,
    required this._uploadTaskAttachment,
    required this._getUsersByBranch,
    required this._notifyTaskEvent,
  }) : super(const TaskState.initial());

  List<TaskEntity> get _tasks =>
      state.maybeWhen(loaded: (t, _, _, _, _) => t, orElse: () => const []);

  /// The currently-loaded task with [id], or null if not in the live list.
  TaskEntity? _taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    // Already streaming this user's tasks — the live Firestore snapshot keeps
    // the list fresh, so a screen revisit must not cancel + re-subscribe (a
    // fresh server read) or flash a skeleton. Still re-load after an error so a
    // revisit can recover; pull-to-refresh passes forceRefresh to re-subscribe.
    final inError = state.maybeWhen(error: (_) => true, orElse: () => false);
    if (!forceRefresh && !inError && _user?.uid == user.uid && _sub != null) {
      return;
    }
    if (_user?.uid != user.uid) {
      _directory.clear();
      _fetchedBranches.clear();
      _branchNames.clear();
    }
    _user = user;
    _loadBranchNames();
    // Only show the full-screen spinner when there's nothing to show yet.
    final hasTasks =
        state.maybeWhen(loaded: (t, _, _, _, _) => true, orElse: () => false);
    if (!hasTasks) emit(const TaskState.loading());
    await _sub?.cancel();
    _sub = _streamFor(user).listen(
      (tasks) {
        // Preserve in-flight submission state — a Firestore write during submit
        // fires this stream, and we must not drop the overlay mid-finalize.
        emit(TaskState.loaded(tasks,
            busy: _mutating,
            directory: _directory,
            isSubmitting: _submitting,
            submissionProgress: _submissionProgress));
        _ensureDirectory(tasks);
      },
      // Capture the real error/stack (a swallowed exception is why this only ever
      // showed a generic UI message — e.g. a missing Firestore composite index
      // surfaces here as `failed-precondition`). The UI message stays friendly.
      onError: (Object error, StackTrace stackTrace) {
        developer.log('Task stream failed for role ${user.role.value}',
            name: 'TaskCubit', error: error, stackTrace: stackTrace);
        emit(const TaskState.error('Failed to load tasks. Please try again.'));
      },
    );
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user, forceRefresh: true);
  }

  Stream<List<TaskEntity>> _streamFor(UserEntity user) {
    if (user.role.isAdmin) return _repository.watchAllTasks();
    if (user.role.isManager) {
      return _repository.watchTasksByBranch(user.branchId ?? '');
    }
    return _repository.watchEmployeeTasks(user.uid);
  }

  /// Loads branchId → name once so the UI can label a task's branch. Re-emits a
  /// fresh loaded state (new directory map reference) so listeners rebuild when
  /// the names arrive. Best-effort — failure leaves names empty (no branch label).
  Future<void> _loadBranchNames() async {
    try {
      final list = await _branchRepository.getBranches();
      for (final b in list) {
        _branchNames[b.id] = b.name;
      }
      if (!isClosed) {
        state.mapOrNull(
          loaded: (s) => emit(s.copyWith(directory: Map.of(_directory))),
        );
      }
    } catch (_) {}
  }

  Future<void> _ensureDirectory(List<TaskEntity> tasks) async {
    final branchIds = <String>{
      for (final t in tasks)
        if ((t.branchId ?? '').isNotEmpty) t.branchId!,
    }..removeAll(_fetchedBranches);
    if (branchIds.isEmpty) return;

    var changed = false;
    for (final branchId in branchIds) {
      _fetchedBranches.add(branchId);
      try {
        final users = await _getUsersByBranch(branchId);
        for (final u in users) {
          _directory[u.uid] = u;
          changed = true;
        }
      } catch (_) {}
    }
    if (changed && !isClosed) {
      state.mapOrNull(
        loaded: (s) => emit(s.copyWith(directory: Map.of(_directory))),
      );
    }
  }

  // ─── Manager / admin actions ───────────────────────────────────
  Future<void> createTask({
    required String title,
    String? description,
    required TaskType type,
    required TaskPriority priority,
    required String branchId,
    DateTime? deadline,
    List<String> assigneeIds = const [],
    List<ChecklistItem> checklist = const [],
    RecurrenceConfig? recurrence,
  }) async {
    TaskEntity? created;
    final ok = await _mutate(() async {
      created = await _createTask(TaskEntity(
        id: '',
        title: title,
        description: description,
        type: type,
        priority: priority,
        branchId: branchId,
        assigneeIds: assigneeIds,
        checklist: checklist,
        recurrence: recurrence,
        createdBy: _user?.uid,
        deadline: deadline,
        activityLog: [
          ActivityEntry(
            status: TaskStatus.pending.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: DateTime.now(),
          ),
        ],
      ));
    });
    // Notify the assignees of the brand-new task (best-effort).
    if (ok && created != null && _user != null && assigneeIds.isNotEmpty) {
      await _notifyTaskEvent(
        task: created!,
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: assigneeIds,
      );
    }
  }

  Future<void> editTask(TaskEntity task) async {
    // Notify only employees newly added by this edit (not the existing ones).
    final before = _taskById(task.id)?.assigneeIds.toSet() ?? const {};
    final added =
        task.assigneeIds.where((id) => !before.contains(id)).toList();
    final ok = await _mutate(() => _updateTask(task));
    if (ok && added.isNotEmpty && _user != null) {
      await _notifyTaskEvent(
        task: task,
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: added,
      );
    }
  }

  Future<void> deleteTask(String taskId) =>
      _mutate(() => _deleteTask(taskId));

  Future<void> assignEmployees({
    required String taskId,
    required List<String> employeeIds,
    String? shiftId,
  }) async {
    final existing = _taskById(taskId);
    final before = existing?.assigneeIds.toSet() ?? const {};
    final added = employeeIds.where((id) => !before.contains(id)).toList();
    final ok = await _mutate(() => _assignTask(
          taskId: taskId,
          employeeIds: employeeIds,
          assignedShiftId: shiftId,
        ));
    // Notify the newly-assigned employees (best-effort).
    if (ok && added.isNotEmpty && existing != null && _user != null) {
      await _notifyTaskEvent(
        task: existing.copyWith(assigneeIds: employeeIds),
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: added,
      );
    }
  }

  Future<void> approveTask(TaskEntity task, {String? reviewNotes}) async {
    final ok = await _transitionMutate(
      task,
      TaskStatus.approved,
      () async {
        final now = DateTime.now();
        await _updateTask(task.copyWith(
          status: TaskStatus.approved,
          approvedBy: _user?.uid,
          approvedAt: now,
          reviewNotes: reviewNotes,
          requiresRework: false,
          activityLog: [
            ...task.activityLog,
            ActivityEntry(
              status: TaskStatus.approved.value,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: now,
              note: reviewNotes,
            ),
          ],
        ));
        if (task.recurrence != null &&
            task.recurrence!.frequency.value != 'none') {
          await _spawnNextRecurrence(task);
        }
      },
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task,
        type: NotificationType.taskApproved,
        actor: _user!,
      );
    }
  }

  /// Sends a task back to be redone (the "Request Rework" review action). Bumps
  /// [TaskEntity.revisionNumber], flags [TaskEntity.requiresRework], stores the
  /// [reviewNotes] as the rejection reason, and notifies the assignees
  /// ([NotificationType.taskRework] → `REWORK #n` badge). Distinct from a
  /// terminal [rejectTask].
  Future<void> reworkTask(TaskEntity task, {String? reviewNotes}) async {
    final nextRevision = task.revisionNumber + 1;
    final ok = await _transitionMutate(
      task,
      TaskStatus.rejected,
      () async {
        final now = DateTime.now();
        await _updateTask(task.copyWith(
          status: TaskStatus.rejected,
          requiresRework: true,
          revisionNumber: nextRevision,
          rejectionReason: reviewNotes,
          rejectedBy: _user?.uid,
          rejectedAt: now,
          reviewNotes: reviewNotes,
          activityLog: [
            ...task.activityLog,
            ActivityEntry(
              // Stored as `rejected` so the existing timeline rendering is
              // unchanged; the rework distinction lives in requiresRework /
              // revisionNumber + the notification type.
              status: TaskStatus.rejected.value,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: now,
              note: reviewNotes,
            ),
          ],
        ));
      },
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task.copyWith(
          revisionNumber: nextRevision,
          requiresRework: true,
          rejectionReason: reviewNotes,
        ),
        type: NotificationType.taskRework,
        actor: _user!,
      );
    }
  }

  /// Terminal rejection (the distinct "Reject" review action). Does **not** bump
  /// the revision count or flag rework; notifies the assignees
  /// ([NotificationType.taskRejected] → red `Rejected` badge).
  Future<void> rejectTask(TaskEntity task, {String? reviewNotes}) async {
    final ok = await _transitionMutate(
      task,
      TaskStatus.rejected,
      () async {
        final now = DateTime.now();
        await _updateTask(task.copyWith(
          status: TaskStatus.rejected,
          requiresRework: false,
          rejectionReason: reviewNotes,
          rejectedBy: _user?.uid,
          rejectedAt: now,
          reviewNotes: reviewNotes,
          activityLog: [
            ...task.activityLog,
            ActivityEntry(
              status: TaskStatus.rejected.value,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: now,
              note: reviewNotes,
            ),
          ],
        ));
      },
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task.copyWith(rejectionReason: reviewNotes),
        type: NotificationType.taskRejected,
        actor: _user!,
      );
    }
  }

  // ─── Employee actions ──────────────────────────────────────────
  Future<void> startTask(TaskEntity task) => _transitionMutate(
        task,
        TaskStatus.started,
        () async {
          final now = DateTime.now();
          await _updateTask(task.copyWith(
            status: TaskStatus.started,
            startedAt: now,
            activityLog: [
              ...task.activityLog,
              ActivityEntry(
                status: TaskStatus.started.value,
                actorId: _user?.uid ?? '',
                actorName: _user?.displayName,
                at: now,
              ),
            ],
          ));
        },
      );

  Future<void> toggleChecklistItem(TaskEntity task, String itemId) {
    final updated = [
      for (final i in task.checklist)
        if (i.id == itemId)
          ChecklistItem(
            id: i.id,
            title: i.title,
            isRequired: i.isRequired,
            completed: !i.completed,
            completedAt: i.completed ? null : DateTime.now(),
          )
        else
          i,
    ];
    return _mutate(() => _updateTask(task.copyWith(checklist: updated)));
  }

  Future<void> submitForReview(TaskEntity task) async {
    final ok = await _transitionMutate(
      task,
      TaskStatus.waitingReview,
      () async {
        final now = DateTime.now();
        await _updateTask(task.copyWith(
          status: TaskStatus.waitingReview,
          submittedAt: now,
          // Resubmitting clears the rework flag (the redo is in for review).
          requiresRework: false,
          activityLog: [
            ...task.activityLog,
            ActivityEntry(
              status: TaskStatus.waitingReview.value,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: now,
            ),
          ],
        ));
      },
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task,
        type: NotificationType.taskSubmitted,
        actor: _user!,
      );
    }
  }

  /// Completes + submits a task for review in a single action (so the employee
  /// doesn't re-open the task to hit "Submit for Review").
  ///
  /// Media is uploaded **before** the status write: if any upload fails the
  /// whole transition is aborted — the task stays `started`, the real Storage
  /// error is surfaced, and the employee keeps their selected media to retry.
  /// Evidence the review depends on must never be silently dropped. The uploaded
  /// [attachments] are attached to the **submission event** (Phase 10), and the
  /// first image also mirrors to the legacy `proofImageUrl` so older surfaces
  /// keep working. Returns true only when the submission actually persisted.
  Future<bool> completeAndSubmit(
    TaskEntity task, {
    String? notes,
    List<PickedAttachment> attachments = const [],
  }) async {
    if (task.status != TaskStatus.started) {
      _emitTransientError(
          "That action isn't allowed for this task's current status.");
      return false;
    }
    if (!task.requiredChecklistComplete) {
      _emitTransientError(
          'Complete all required checklist items before submitting.');
      return false;
    }
    if (_user == null || _mutating) return false;

    final prev = _tasks;
    _mutating = true;
    _submitting = true;

    // Throttled progress → state: emit only on a stage change or a whole-percent
    // change, so the screen never rebuilds faster than it needs to.
    SubmissionStage? lastStage;
    int? lastPercent;
    void setProgress(SubmissionProgress p) {
      if (isClosed) return;
      if (p.stage == lastStage && p.percent == lastPercent) return;
      lastStage = p.stage;
      lastPercent = p.percent;
      _submissionProgress = p;
      emit(TaskState.loaded(_tasks,
          busy: true,
          directory: _directory,
          isSubmitting: true,
          submissionProgress: p));
    }

    try {
      setProgress(const SubmissionProgress(SubmissionStage.preparing));

      // Upload in parallel (order preserved by Future.wait), reporting aggregate
      // byte progress. Any failure throws → the write is aborted and the real
      // error surfaced, keeping the employee's selection.
      setProgress(const SubmissionProgress(SubmissionStage.uploading));
      final transferred = List<int>.filled(attachments.length, 0);
      final totals = List<int>.filled(attachments.length, 0);
      void report() => setProgress(SubmissionProgress(
            SubmissionStage.uploading,
            transferredBytes: transferred.fold(0, (a, b) => a + b),
            totalBytes: totals.fold(0, (a, b) => a + b),
          ));

      final futures = <Future<TaskAttachment>>[];
      for (var i = 0; i < attachments.length; i++) {
        final idx = i; // capture per-iteration for the progress closure
        final a = attachments[idx];
        futures.add(_uploadTaskAttachment(
          taskId: task.id,
          file: a.file,
          type: a.type,
          uploadedBy: _user?.uid ?? '',
          uploadedByName: _user?.displayName,
          durationMs: a.durationMs,
          onProgress: (sent, total) {
            transferred[idx] = sent;
            totals[idx] = total;
            report();
          },
        ));
      }
      final uploaded = await Future.wait(futures);

      setProgress(const SubmissionProgress(SubmissionStage.finalizing));
      String? firstImage;
      for (final a in uploaded) {
        if (a.type == AttachmentType.image) {
          firstImage = a.url;
          break;
        }
      }
      final now = DateTime.now();
      await _updateTask(task.copyWith(
        status: TaskStatus.waitingReview,
        submittedAt: now,
        notes: notes ?? task.notes,
        // Resubmitting clears the rework flag (the redo is in for review).
        requiresRework: false,
        // Mirror the first image to the legacy field for back-compat.
        proofImageUrl: firstImage ?? task.proofImageUrl,
        activityLog: [
          ...task.activityLog,
          ActivityEntry(
            status: TaskStatus.completed.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: now,
            note: notes,
            attachments: uploaded,
          ),
          ActivityEntry(
            status: TaskStatus.waitingReview.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: now.add(const Duration(milliseconds: 1)),
          ),
        ],
      ));

      _mutating = false;
      _submitting = false;
      _submissionProgress = null;
      // The Firestore write already pushed the new state through the stream;
      // emit once more to clear the submission flags immediately.
      if (!isClosed) {
        emit(TaskState.loaded(_tasks, busy: false, directory: _directory));
      }
      // Notify the reviewer who created the task (best-effort).
      if (_user != null) {
        await _notifyTaskEvent(
          task: task,
          type: NotificationType.taskSubmitted,
          actor: _user!,
        );
      }
      return true;
    } on Failure catch (e) {
      _mutating = false;
      _submitting = false;
      _submissionProgress = null;
      emit(TaskState.error(e.message));
      emit(TaskState.loaded(prev, directory: _directory));
      return false;
    } catch (_) {
      _mutating = false;
      _submitting = false;
      _submissionProgress = null;
      emit(const TaskState.error('Something went wrong. Please try again.'));
      emit(TaskState.loaded(prev, directory: _directory));
      return false;
    }
  }

  // ─── Picker support ────────────────────────────────────────────
  Future<List<UserEntity>> branchEmployees(String branchId) async {
    try {
      final users = await _getUsersByBranch(branchId);
      return users.where((u) => u.role.isEmployee).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<BranchEntity>> branches() async {
    try {
      final list = await _branchRepository.getBranches();
      return list.where((b) => b.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Task templates ────────────────────────────────────────────
  Future<List<TaskTemplateEntity>> templates({String? branchId}) async {
    try {
      final all = await _repository.getTemplates();
      if (branchId == null || branchId.isEmpty) return all;
      return all
          .where((t) =>
              (t.branchId ?? '').isEmpty || t.branchId == branchId)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTemplate({
    required String title,
    String? description,
    required TaskType type,
    required TaskPriority priority,
    String? branchId,
    List<ChecklistItemTemplate> checklistItems = const [],
  }) =>
      _repository.createTemplate(TaskTemplateEntity(
        id: '',
        title: title,
        description: description,
        type: type,
        priority: priority,
        branchId: branchId,
        checklistItems: checklistItems,
        createdBy: _user?.uid,
      ));

  Future<void> deleteTemplate(String templateId) =>
      _repository.deleteTemplate(templateId);

  // ─── Internals ─────────────────────────────────────────────────
  /// Creates the next instance of a recurring task immediately after [source]
  /// is approved. Resets checklist items to uncompleted; inherits everything
  /// else (title, description, type, priority, branchId, assignees, recurrence).
  Future<void> _spawnNextRecurrence(TaskEntity source) async {
    final recurrence = source.recurrence!;
    final nextDeadline =
        recurrence.nextOccurrence(source.deadline ?? DateTime.now());
    final freshChecklist = [
      for (final item in source.checklist)
        ChecklistItem(
          id: item.id,
          title: item.title,
          isRequired: item.isRequired,
          completed: false,
          completedAt: null,
        ),
    ];
    try {
      await _createTask(TaskEntity(
        id: '',
        title: source.title,
        description: source.description,
        type: source.type,
        priority: source.priority,
        branchId: source.branchId,
        assigneeIds: source.assigneeIds,
        checklist: freshChecklist,
        recurrence: recurrence,
        createdBy: source.createdBy,
        deadline: nextDeadline,
        activityLog: [
          ActivityEntry(
            status: TaskStatus.pending.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: DateTime.now(),
            note: 'Auto-created (recurring)',
          ),
        ],
      ));
    } catch (_) {
      // Recurrence spawn is best-effort; the approval itself already succeeded.
    }
  }

  /// Runs a write [action] with optimistic busy state. Returns true on success;
  /// on failure it surfaces the error and rolls the list back to [prev].
  Future<bool> _mutate(Future<void> Function() action) async {
    if (_user == null || _mutating) return false;
    final prev = _tasks;
    _mutating = true;
    emit(TaskState.loaded(prev, busy: true, directory: _directory));
    try {
      await action();
      _mutating = false;
      emit(TaskState.loaded(_tasks, busy: false, directory: _directory));
      return true;
    } on Failure catch (e) {
      _mutating = false;
      emit(TaskState.error(e.message));
      emit(TaskState.loaded(prev, directory: _directory));
      return false;
    } catch (_) {
      _mutating = false;
      emit(const TaskState.error('Something went wrong. Please try again.'));
      emit(TaskState.loaded(prev, directory: _directory));
      return false;
    }
  }

  Future<bool> _transitionMutate(
    TaskEntity task,
    TaskStatus to,
    Future<void> Function() action,
  ) {
    if (!_canTransition(task.status, to)) {
      _emitTransientError(
          "That action isn't allowed for this task's current status.");
      return Future.value(false);
    }
    return _mutate(action);
  }

  /// Emits a one-shot error (for the UI's snackbar listener) then immediately
  /// restores the loaded list so the screen isn't left stuck on an error state.
  void _emitTransientError(String message) {
    final prev = _tasks;
    emit(TaskState.error(message));
    emit(TaskState.loaded(prev, directory: _directory));
  }

  static bool _canTransition(TaskStatus from, TaskStatus to) {
    switch (from) {
      case TaskStatus.pending:
        return to == TaskStatus.started;
      case TaskStatus.started:
        // completeAndSubmit goes started → waitingReview directly (skipping completed)
        return to == TaskStatus.completed || to == TaskStatus.waitingReview;
      case TaskStatus.completed:
        return to == TaskStatus.waitingReview;
      case TaskStatus.waitingReview:
        return to == TaskStatus.approved || to == TaskStatus.rejected;
      case TaskStatus.rejected:
        return to == TaskStatus.started;
      case TaskStatus.approved:
        return false;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
