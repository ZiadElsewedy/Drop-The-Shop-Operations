import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurrence_config.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/domain/note_category.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/task_ordering.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/domain/work_types/task_work_x.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/submission_progress.dart';
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
  final ScheduleRepository _scheduleRepository;
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final AssignTask _assignTask;
  final UploadTaskAttachment _uploadTaskAttachment;
  final GetUsersByBranch _getUsersByBranch;
  final NotifyTaskEvent _notifyTaskEvent;

  UserEntity? _user;
  /// One subscription per task source feeding the current scope. Admin/manager
  /// have exactly one (all tasks / branch tasks); an employee has one for their
  /// individually-assigned tasks plus one per shift they're rostered on today
  /// (Shift Assignment feature) — see [_subscribeFor]/[_updateSource].
  final List<StreamSubscription<List<TaskEntity>>> _subs = [];
  final Map<String, List<TaskEntity>> _taskSources = {};
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
    required this._scheduleRepository,
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

  /// Identifies which Firestore stream the current subscription is bound to.
  /// Role and branch select **different** streams ([_streamFor]: admin →
  /// `watchAllTasks`, manager → `watchTasksByBranch`, employee →
  /// `watchEmployeeTasks`), so the subscription's identity is the full scope, not
  /// just the uid — a same-uid role/branch change (e.g. an employee promoted to
  /// manager, or moved branches, while the app is active) must force a
  /// resubscribe or we'd keep streaming the wrong scope.
  static String _scopeKey(UserEntity u) =>
      '${u.uid}:${u.role.value}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    // Already streaming this exact scope — the live Firestore snapshot keeps the
    // list fresh, so a screen revisit must not cancel + re-subscribe (a fresh
    // server read) or flash a skeleton. Still re-load after an error so a revisit
    // can recover; pull-to-refresh passes forceRefresh to re-subscribe.
    final inError = state.maybeWhen(error: (_) => true, orElse: () => false);
    final sameScope = _user != null && _scopeKey(_user!) == _scopeKey(user);
    if (!forceRefresh && !inError && _subs.isNotEmpty && sameScope) {
      return;
    }
    // Scope changed (different user, or same user with a new role/branch) — the
    // resolved directory + branch caches belonged to the old scope, so drop them.
    if (!sameScope) {
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
    await _cancelSubs();
    _taskSources.clear();
    await _subscribeFor(user);
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user, forceRefresh: true);
  }

  Future<void> _cancelSubs() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  /// Sets up every task source for [user]'s scope. Admin/manager get exactly
  /// one (unchanged from before shift assignment). An employee gets their
  /// individually/team-assigned stream **plus** one shift stream per shift
  /// they're rostered on today (0, 1, or 2 — `shiftsFor` may return both) — a
  /// shift task's `assigneeIds` is empty, so it would never appear in
  /// `watchEmployeeTasks` alone.
  Future<void> _subscribeFor(UserEntity user) async {
    if (user.role.isAdmin) {
      _subscribe('all', _repository.watchAllTasks());
      return;
    }
    if (user.role.isManager) {
      _subscribe('branch', _repository.watchTasksByBranch(user.branchId ?? ''));
      return;
    }
    _subscribe('assignee', _repository.watchEmployeeTasks(user.uid));
    await _subscribeEmployeeShifts(user);
  }

  void _subscribe(String sourceKey, Stream<List<TaskEntity>> stream) {
    _subs.add(stream.listen(
      (tasks) => _updateSource(sourceKey, tasks),
      // Capture the real error/stack (a swallowed exception is why this only
      // ever showed a generic UI message — e.g. a missing Firestore composite
      // index surfaces here as `failed-precondition`). The UI message stays
      // friendly.
      onError: (Object error, StackTrace stackTrace) {
        developer.log('Task stream "$sourceKey" failed',
            name: 'TaskCubit', error: error, stackTrace: stackTrace);
        emit(const TaskState.error('Failed to load tasks. Please try again.'));
      },
    ));
  }

  /// Resolves the employee's shift(s) today from the branch's weekly schedule
  /// (`ScheduleRepository.getSchedule` + `WeeklyScheduleEntity.shiftsFor` —
  /// exactly the primitives `computeBranchWorkload` already uses for the same
  /// "who's on shift X today" question) and subscribes one `watchShiftTasks`
  /// stream per shift. Resolved once per `load()` call; `refresh()` re-resolves.
  /// Best-effort — an employee with no branch or no resolvable schedule simply
  /// gets no shift streams (unchanged behaviour from before this feature).
  Future<void> _subscribeEmployeeShifts(UserEntity user) async {
    final branchId = user.branchId;
    if (branchId == null || branchId.isEmpty) return;
    try {
      final schedule = await _scheduleRepository.getSchedule(
          branchId, ScheduleWeek.currentWeekStart());
      if (schedule == null) return;
      final today = ScheduleDay.today();
      for (final shift in schedule.shiftsFor(user.uid, today)) {
        _subscribe(
          'shift:${shift.value}',
          _repository.watchShiftTasks(branchId: branchId, shift: shift),
        );
      }
    } catch (_) {
      // Best-effort — see doc comment.
    }
  }

  /// Scheduling V2 smart default — resolve the rostered shift of the given
  /// [uids] on [date] in [branchId], to pre-fill a non-shift task's schedule.
  /// Returns [AssigneeShiftFit.unanimous] with the shift when everyone shares one,
  /// [AssigneeShiftFit.mixed] when they differ (the form asks the user to choose),
  /// or [AssigneeShiftFit.none] when nobody's rostered / no schedule. Best-effort
  /// (a read error degrades to `none` — the manager just schedules manually).
  Future<({AssigneeShiftFit fit, ScheduleShift? shift})> resolveAssigneeShift({
    required String branchId,
    required List<String> uids,
    required DateTime date,
  }) async {
    if (branchId.isEmpty || uids.isEmpty) {
      return (fit: AssigneeShiftFit.none, shift: null);
    }
    try {
      final schedule =
          await _scheduleRepository.getSchedule(branchId, ScheduleWeek.startOf(date));
      if (schedule == null) return (fit: AssigneeShiftFit.none, shift: null);
      final day = ScheduleDay.fromDate(date);
      return assigneeShiftFit([
        for (final uid in uids) schedule.shiftsFor(uid, day),
      ]);
    } catch (_) {
      return (fit: AssigneeShiftFit.none, shift: null);
    }
  }

  /// Merges every task source's latest snapshot (keyed by source, each holding
  /// that source's *full* current result set) into one deduped-by-id list and
  /// emits it. A task disappearing from its source's next snapshot (reassigned,
  /// deleted, no longer matching a query) is naturally dropped on the next
  /// merge — no stale entries linger.
  void _updateSource(String sourceKey, List<TaskEntity> tasks) {
    _taskSources[sourceKey] = tasks;
    final merged = <String, TaskEntity>{};
    for (final list in _taskSources.values) {
      for (final t in list) {
        merged[t.id] = t;
      }
    }
    final combined = sortTasksNewestFirst(merged.values.toList());
    // Preserve in-flight submission state — a Firestore write during submit
    // fires this stream, and we must not drop the overlay mid-finalize.
    emit(TaskState.loaded(combined,
        busy: _mutating,
        directory: _directory,
        isSubmitting: _submitting,
        submissionProgress: _submissionProgress));
    _ensureDirectory(combined);
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
    } catch (e) {
      AppLog.warning('task', 'branch-name enrichment failed: $e');
    }
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
      } catch (e) {
        AppLog.warning('task', 'member-directory enrichment failed: $e');
      }
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
    /// The operational work type (Registry id — `general`, `transfer`,
    /// `inventoryCount`, …). Defaults to `general` so every existing call site
    /// (recurrence spawn, template materialize) is unaffected.
    String workType = 'general',
    /// Schema-driven values for [workType]'s dynamic fields.
    Map<String, dynamic> data = const {},
    required TaskPriority priority,
    required String branchId,
    /// Task Scheduling V2 — when the task is scheduled to start (smart-defaulted
    /// from the shift in the form, fully overridable). Additive/optional; every
    /// existing call site omits it (→ null).
    DateTime? startsAt,
    DateTime? deadline,
    List<String> assigneeIds = const [],
    List<ChecklistItem> checklist = const [],
    RecurrenceConfig? recurrence,
    List<PickedAttachment> referenceAttachments = const [],
    /// Shift Assignment feature. Defaults to [TaskAssignmentType.individual]
    /// (existing behaviour, unchanged) for every pre-existing call site.
    TaskAssignmentType assignmentType = TaskAssignmentType.individual,
    /// Required when [assignmentType] is [TaskAssignmentType.shift].
    ScheduleShift? shift,
    /// The day a shift instance is *for*; defaults to [deadline] (date part) or
    /// today when omitted. Ignored for individual/team tasks.
    DateTime? instanceDate,
  }) async {
    // A shift task targets whoever's rostered on `shift`, never named people.
    final isShift = assignmentType == TaskAssignmentType.shift;
    final effectiveAssigneeIds = isShift ? const <String>[] : assigneeIds;
    final effectiveInstanceDate =
        isShift ? (instanceDate ?? deadline ?? DateTime.now()) : null;

    TaskEntity? created;
    final ok = await _mutate(() async {
      created = await _createTask(TaskEntity(
        id: '',
        title: title,
        description: description,
        type: type,
        workType: workType,
        data: data,
        priority: priority,
        branchId: branchId,
        assigneeIds: effectiveAssigneeIds,
        checklist: checklist,
        recurrence: recurrence,
        assignmentType: assignmentType,
        shift: shift,
        instanceDate: effectiveInstanceDate,
        createdBy: _user?.uid,
        startsAt: startsAt,
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
      // Reference images upload AFTER create (the Storage path needs the task
      // id), then patch the task. Best-effort relative to the task itself: a
      // failed upload throws inside _mutate, which rolls the list back so the
      // manager can retry — the half-created task without images would be worse.
      if (referenceAttachments.isNotEmpty && created != null) {
        final uploaded =
            await _uploadReferences(created!.id, referenceAttachments);
        created = created!.copyWith(referenceAttachments: uploaded);
        await _updateTask(created!);
      }
    });
    if (!ok || created == null || _user == null) return;

    // Notify (best-effort) — a shift task resolves its recipients from today's
    // roster instead of a fixed assignee list; reuses the same NotifyTaskEvent
    // call individual/team assignment already uses, just with a different
    // recipient source.
    if (isShift && shift != null) {
      final recipients = await _shiftRecipients(
        branchId: branchId,
        shift: shift,
        day: effectiveInstanceDate!,
      );
      if (recipients.isNotEmpty) {
        await _notifyTaskEvent(
          task: created!,
          type: NotificationType.taskAssigned,
          actor: _user!,
          recipientOverride: recipients,
        );
      }
    } else if (assigneeIds.isNotEmpty) {
      await _notifyTaskEvent(
        task: created!,
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: assigneeIds,
      );
    }
  }

  /// The uids rostered on [shift] for [day] at [branchId] — the recipients for
  /// a shift task's assignment notification. Reuses the exact schedule lookup
  /// (`ScheduleRepository.getSchedule` + `WeeklyScheduleEntity.employeesFor`)
  /// `computeBranchWorkload` already relies on. Best-effort: no schedule ⇒ no
  /// recipients, never throws.
  Future<List<String>> _shiftRecipients({
    required String branchId,
    required ScheduleShift shift,
    required DateTime day,
  }) async {
    try {
      final schedule =
          await _scheduleRepository.getSchedule(branchId, ScheduleWeek.startOf(day));
      if (schedule == null) return const [];
      return schedule.employeesFor(ScheduleDay.fromDate(day), shift);
    } catch (_) {
      return const [];
    }
  }

  Future<void> editTask(
    TaskEntity task, {
    List<PickedAttachment> newReferenceAttachments = const [],
  }) async {
    // An approved task is a locked, reviewed record — block edits/reassignment
    // (the UI hides the affordance; this is the cubit-level backstop). An admin
    // must reopen it first (reopenTask).
    if (_taskById(task.id)?.status == TaskStatus.approved) {
      _emitTransientError('Approved tasks are locked. Reopen the task to edit it.');
      return;
    }
    // Notify only employees newly added by this edit (not the existing ones).
    final before = _taskById(task.id)?.assigneeIds.toSet() ?? const {};
    final added =
        task.assigneeIds.where((id) => !before.contains(id)).toList();
    final ok = await _mutate(() async {
      // [task] already carries the kept reference images (the form drops removed
      // ones); upload any newly-picked ones and append before the write.
      var next = task;
      if (newReferenceAttachments.isNotEmpty) {
        final uploaded =
            await _uploadReferences(task.id, newReferenceAttachments);
        next = task.copyWith(
          referenceAttachments: [...task.referenceAttachments, ...uploaded],
        );
      }
      await _updateTask(next);
    });
    if (ok && added.isNotEmpty && _user != null) {
      await _notifyTaskEvent(
        task: task,
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: added,
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (_taskById(taskId)?.status == TaskStatus.approved) {
      _emitTransientError(
          'Approved tasks are locked. Reopen the task before deleting it.');
      return;
    }
    await _mutate(() => _deleteTask(taskId));
  }

  /// Admin escape hatch — reopens an approved task for correction. Moves it back
  /// to `started` (clearing the approval audit) and logs the reopen on the
  /// timeline, so a mistaken approval is recoverable. Wired only behind an
  /// admin-gated affordance; `firestore.rules` permits only an admin to move a
  /// task out of `approved`.
  Future<void> reopenTask(TaskEntity task) async {
    if (task.status != TaskStatus.approved) return;
    await _mutate(() async {
      final now = DateTime.now();
      await _updateTask(task.copyWith(
        status: TaskStatus.started,
        approvedBy: null,
        approvedAt: null,
        // Reopening a task that the retention pass had archived brings it back
        // into active views (it's no longer an approved historical record).
        archivedAt: null,
        requiresRework: false,
        activityLog: [
          ...task.activityLog,
          ActivityEntry(
            status: TaskStatus.started.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: now,
            note: 'Reopened for changes',
          ),
        ],
      ));
    });
  }

  Future<void> assignEmployees({
    required String taskId,
    required List<String> employeeIds,
    String? shiftId,
  }) async {
    final existing = _taskById(taskId);
    if (existing?.status == TaskStatus.approved) {
      _emitTransientError(
          'Approved tasks are locked. Reopen the task to change assignees.');
      return;
    }
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

  /// Merges [patch] into the task's schema-driven work-type [TaskEntity.data] —
  /// the employee-captured completion fields (a counted quantity, an amount
  /// spent, inspection results). A single `_updateTask` write; a `null` value in
  /// [patch] removes the key. Permitted for an assignee by the deployed rules
  /// (it's an ordinary field like notes/checklist — no frozen field is touched).
  Future<void> updateWorkData(TaskEntity task, Map<String, dynamic> patch) {
    if (patch.isEmpty) return Future<void>.value();
    final next = {...task.data};
    patch.forEach((k, v) {
      if (v == null) {
        next.remove(k);
      } else {
        next[k] = v;
      }
    });
    return _mutate(() => _updateTask(task.copyWith(data: next)));
  }

  /// Records a per-type [WorkEvent] milestone on the timeline (a transfer's
  /// "dispatched" / "received", a purchase's "purchased", …). The milestone
  /// rides `ActivityEntry.status` as its [eventId], so it renders on the generic
  /// activity timeline with no core-status change. Idempotent — a no-op if the
  /// milestone is already logged.
  Future<void> logWorkEvent(
    TaskEntity task, {
    required String eventId,
    String? note,
  }) {
    if (task.activityLog.any((e) => e.status == eventId)) {
      return Future<void>.value();
    }
    return _mutate(() => _updateTask(task.copyWith(
          activityLog: [
            ...task.activityLog,
            ActivityEntry(
              status: eventId,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: DateTime.now(),
              note: note,
            ),
          ],
        )));
  }

  /// Appends a manager/admin operational **note** to the task's timeline WITHOUT
  /// a status change — fast feedback from the feed's triage surface. No-op on
  /// blank text. The [category] (info / warning / issue) sets the note's
  /// activity kind so `activity_format` can render its hierarchy.
  Future<void> addNote(
    TaskEntity task,
    String note, {
    NoteCategory category = NoteCategory.info,
  }) {
    final text = note.trim();
    if (text.isEmpty) return Future<void>.value();
    return _mutate(() => _updateTask(task.copyWith(
          activityLog: [
            ...task.activityLog,
            ActivityEntry(
              status: category.activityStatus,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: DateTime.now(),
              note: text,
            ),
          ],
        )));
  }

  Future<void> submitForReview(TaskEntity task) async {
    final submission =
        task.workDefinition.validateSubmission(task.workContext);
    if (!submission.ok) {
      _emitTransientError(
          submission.firstError ?? "This task isn't ready to submit yet.");
      return;
    }
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
    // The work type owns its completion gate (a general task = required checklist
    // items done; an inventory count = a counted quantity; a transfer = a
    // handover photo). Proof being uploaded *now* counts toward the gate.
    final submission = task.workDefinition.validateSubmission(
      task.workContext.withPendingProof(attachments.length),
    );
    if (!submission.ok) {
      _emitTransientError(
          submission.firstError ?? "This task isn't ready to submit yet.");
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

  // ─── Recurring shift-task templates ────────────────────────────
  Future<List<RecurringTaskTemplateEntity>> recurringTemplates(
      String branchId) async {
    try {
      return await _repository.getRecurringTemplates(branchId);
    } catch (_) {
      return const [];
    }
  }

  /// Creates a daily/weekly recurring shift-task template, then starts a
  /// best-effort materialization of *today's* instance (if due today) without
  /// blocking the Save UI on the follow-up task/roster/notification I/O. The
  /// scheduled Cloud Function remains the fallback if that background work
  /// cannot complete.
  Future<void> createRecurringShiftTemplate({
    required String title,
    String? description,
    required TaskPriority priority,
    required String branchId,
    required ScheduleShift shift,
    List<ChecklistItemTemplate> checklistItems = const [],
    required TemplateRepeatMode repeat,
    int weekday = 1,
  }) async {
    final created = await _repository.createRecurringTemplate(
      RecurringTaskTemplateEntity(
        id: '',
        title: title,
        description: description,
        priority: priority,
        checklistItems: checklistItems,
        branchId: branchId,
        shift: shift,
        repeat: repeat,
        weekday: weekday,
        createdBy: _user?.uid,
      ),
    );
    unawaited(_materializeTodayInstance(created));
  }

  Future<void> setRecurringTemplateActive(
    RecurringTaskTemplateEntity template,
    bool active,
  ) =>
      _repository.updateRecurringTemplate(template.copyWith(active: active));

  Future<void> deleteRecurringTemplate(String templateId) =>
      _repository.deleteRecurringTemplate(templateId);

  /// Creates *today's* instance of [template] at the same deterministic id
  /// (`rt_{templateId}_{yyyy-MM-dd}`, UTC) the `generateShiftTaskInstances`
  /// Cloud Function uses, so the two can never double-create the same day's
  /// instance. A no-op when [template] isn't due today (weekly, wrong weekday)
  /// or an instance for today already exists. Best-effort: the template save
  /// already succeeded, and the Cloud Function will generate the instance on
  /// its next scheduled run if this fails.
  Future<void> _materializeTodayInstance(
      RecurringTaskTemplateEntity template) async {
    final utcNow = DateTime.now().toUtc();
    if (template.repeat == TemplateRepeatMode.weekly &&
        template.weekday != utcNow.weekday) {
      return;
    }
    final today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final instanceId = 'rt_${template.id}_${_dateKey(today)}';
    final instance = TaskEntity(
      id: instanceId,
      title: template.title,
      description: template.description,
      type: TaskType.daily,
      priority: template.priority,
      branchId: template.branchId,
      checklist: template.buildTaskChecklist(),
      assignmentType: TaskAssignmentType.shift,
      shift: template.shift,
      instanceDate: today,
      sourceTemplateId: template.id,
      createdBy: _user?.uid,
      activityLog: [
        ActivityEntry(
          status: TaskStatus.pending.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: utcNow,
        ),
      ],
    );
    try {
      final createdInstance = await _repository.createTaskWithId(instance);
      if (createdInstance == null) return; // already generated today
      final recipients = await _shiftRecipients(
        branchId: template.branchId,
        shift: template.shift,
        day: today,
      );
      if (recipients.isNotEmpty && _user != null) {
        await _notifyTaskEvent(
          task: createdInstance,
          type: NotificationType.taskAssigned,
          actor: _user!,
          recipientOverride: recipients,
        );
      }
    } catch (_) {
      // Best-effort — see doc comment.
    }
  }

  static String _dateKey(DateTime utcDate) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utcDate.year}-${two(utcDate.month)}-${two(utcDate.day)}';
  }

  // ─── Internals ─────────────────────────────────────────────────
  /// Uploads the manager/admin's picked reference images for [taskId] (in
  /// parallel) and returns the resolved [TaskAttachment]s. Used by create/edit;
  /// a failure propagates so the caller's [_mutate] rolls back and surfaces it.
  Future<List<TaskAttachment>> _uploadReferences(
    String taskId,
    List<PickedAttachment> picked,
  ) =>
      Future.wait([
        for (final p in picked)
          _uploadTaskAttachment(
            taskId: taskId,
            file: p.file,
            type: p.type,
            uploadedBy: _user?.uid ?? '',
            uploadedByName: _user?.displayName,
            durationMs: p.durationMs,
          ),
      ]);

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
        assignmentType: source.assignmentType,
        shift: source.shift,
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
    for (final s in _subs) {
      s.cancel();
    }
    return super.close();
  }
}
