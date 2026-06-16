import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';
import 'package:fbro/features/task/domain/usecases/assign_task.dart';
import 'package:fbro/features/task/domain/usecases/change_task_status.dart';
import 'package:fbro/features/task/domain/usecases/create_task.dart';
import 'package:fbro/features/task/domain/usecases/delete_task.dart';
import 'package:fbro/features/task/domain/usecases/review_task.dart';
import 'package:fbro/features/task/domain/usecases/update_task.dart';
import 'package:fbro/features/task/domain/usecases/upload_task_proof.dart';
import 'task_state.dart';

/// Drives the task workflow for all three roles. The list loaded depends on the
/// signed-in user's role (admin: all · manager: own branch · employee: own
/// tasks) and is now **realtime** — a Firestore snapshot stream, so a task an
/// employee is assigned (or any status change) appears immediately, with no
/// manual refresh, backed by the offline cache. Workflow transitions are
/// validated here ([_canTransition]); the branch/role write rules are enforced
/// server-side in `firestore.rules`.
class TaskCubit extends Cubit<TaskState> {
  final TaskRepository _repository; // realtime streams + templates
  final BranchRepository _branchRepository; // branch picker (admin task form)
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final AssignTask _assignTask;
  final ChangeTaskStatus _changeTaskStatus;
  final ReviewTask _reviewTask;
  final UploadTaskProof _uploadTaskProof;
  final GetUsersByBranch _getUsersByBranch;

  /// The user whose view is currently loaded — used to (re)subscribe.
  UserEntity? _user;

  /// Live subscription to the role-scoped task list.
  StreamSubscription<List<TaskEntity>>? _sub;

  /// True while a write is in flight, so the list stays visible with a busy bar
  /// instead of flickering. Stream emissions during a mutation carry this flag.
  bool _mutating = false;

  TaskCubit({
    required this._repository,
    required this._branchRepository,
    required this._createTask,
    required this._updateTask,
    required this._deleteTask,
    required this._assignTask,
    required this._changeTaskStatus,
    required this._reviewTask,
    required this._uploadTaskProof,
    required this._getUsersByBranch,
  }) : super(const TaskState.initial());

  List<TaskEntity> get _tasks =>
      state.maybeWhen(loaded: (t, _) => t, orElse: () => const []);

  /// Subscribes to the live task list for [user] by role, remembering it so a
  /// pull-to-refresh can re-subscribe. Cancels any previous subscription first.
  Future<void> load(UserEntity user) async {
    _user = user;
    emit(const TaskState.loading());
    await _sub?.cancel();
    _sub = _streamFor(user).listen(
      (tasks) => emit(TaskState.loaded(tasks, busy: _mutating)),
      onError: (_) =>
          emit(const TaskState.error('Failed to load tasks. Please try again.')),
    );
  }

  /// With a live stream this is rarely needed, but pull-to-refresh re-subscribes
  /// (and surfaces a fresh error state if the listener had failed).
  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user);
  }

  Stream<List<TaskEntity>> _streamFor(UserEntity user) {
    if (user.role.isAdmin) return _repository.watchAllTasks();
    if (user.role.isManager) {
      return _repository.watchTasksByBranch(user.branchId ?? '');
    }
    return _repository.watchEmployeeTasks(user.uid);
  }

  // ─── Manager / admin actions ───────────────────────────────────
  Future<void> createTask({
    required String title,
    String? description,
    required TaskType type,
    required TaskPriority priority,
    required String branchId,
    DateTime? deadline,
  }) =>
      _mutate(() => _createTask(TaskEntity(
            id: '',
            title: title,
            description: description,
            type: type,
            priority: priority,
            branchId: branchId,
            createdBy: _user?.uid,
            deadline: deadline,
          )));

  Future<void> editTask(TaskEntity task) => _mutate(() => _updateTask(task));

  Future<void> deleteTask(String taskId) =>
      _mutate(() => _deleteTask(taskId));

  Future<void> assignEmployee({
    required String taskId,
    required String? employeeId,
    String? shiftId,
  }) =>
      _mutate(() => _assignTask(
            taskId: taskId,
            employeeId: employeeId,
            assignedShiftId: shiftId,
          ));

  Future<void> approveTask(TaskEntity task, {String? reviewNotes}) =>
      _transitionMutate(
        task,
        TaskStatus.approved,
        () => _reviewTask(
          taskId: task.id,
          approved: true,
          reviewerId: _user?.uid ?? '',
          reviewNotes: reviewNotes,
        ),
      );

  Future<void> rejectTask(TaskEntity task, {String? reviewNotes}) =>
      _transitionMutate(
        task,
        TaskStatus.rejected,
        () => _reviewTask(
          taskId: task.id,
          approved: false,
          reviewerId: _user?.uid ?? '',
          reviewNotes: reviewNotes,
        ),
      );

  // ─── Employee actions ──────────────────────────────────────────
  Future<void> startTask(TaskEntity task) => _transitionMutate(
        task,
        TaskStatus.started,
        () => _changeTaskStatus(taskId: task.id, status: TaskStatus.started),
      );

  Future<void> completeTask(
    TaskEntity task, {
    String? notes,
    File? proof,
  }) =>
      _transitionMutate(task, TaskStatus.completed, () async {
        final proofUrl =
            proof != null ? await _uploadTaskProof(task.id, proof) : null;
        await _updateTask(task.copyWith(
          status: TaskStatus.completed,
          notes: notes ?? task.notes,
          proofImageUrl: proofUrl ?? task.proofImageUrl,
        ));
      });

  Future<void> submitForReview(TaskEntity task) => _transitionMutate(
        task,
        TaskStatus.waitingReview,
        () => _changeTaskStatus(
          taskId: task.id,
          status: TaskStatus.waitingReview,
        ),
      );

  // ─── Picker support ────────────────────────────────────────────
  /// Branch employees available to assign a task to. Returns [] on failure so
  /// the picker degrades gracefully.
  Future<List<UserEntity>> branchEmployees(String branchId) async {
    try {
      final users = await _getUsersByBranch(branchId);
      return users.where((u) => u.role.isEmployee).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Active branches, for the admin's New Task branch dropdown. Returns [] on
  /// failure so the form still opens.
  Future<List<BranchEntity>> branches() async {
    try {
      final list = await _branchRepository.getBranches();
      return list.where((b) => b.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Task templates (reusable blueprints) ──────────────────────
  /// Templates visible to the current view: GLOBAL templates (no branch) plus
  /// those scoped to [branchId]. An admin (null/empty [branchId]) sees all.
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

  /// Saves a reusable template. Awaited by the template manager sheet (throws on
  /// failure); it does not touch the task-list state.
  Future<void> saveTemplate({
    required String title,
    String? description,
    required TaskType type,
    required TaskPriority priority,
    String? branchId,
  }) =>
      _repository.createTemplate(TaskTemplateEntity(
        id: '',
        title: title,
        description: description,
        type: type,
        priority: priority,
        branchId: branchId,
        createdBy: _user?.uid,
      ));

  Future<void> deleteTemplate(String templateId) =>
      _repository.deleteTemplate(templateId);

  // ─── Internals ─────────────────────────────────────────────────
  /// Runs [action] while keeping the current list visible (busy). The live
  /// stream then emits the updated list automatically; on failure the previous
  /// list is restored and an error surfaced.
  Future<void> _mutate(Future<void> Function() action) async {
    if (_user == null || _mutating) return;
    final prev = _tasks;
    _mutating = true;
    emit(TaskState.loaded(prev, busy: true));
    try {
      await action();
      _mutating = false;
      // The stream usually has already emitted the new list (cache reflects the
      // write); clear busy explicitly in case it is slow (e.g. offline).
      emit(TaskState.loaded(_tasks, busy: false));
    } on Failure catch (e) {
      _mutating = false;
      emit(TaskState.error(e.message));
      emit(TaskState.loaded(prev));
    } catch (_) {
      _mutating = false;
      emit(const TaskState.error('Something went wrong. Please try again.'));
      emit(TaskState.loaded(prev));
    }
  }

  /// Validates the [from → to] transition before running [action].
  Future<void> _transitionMutate(
    TaskEntity task,
    TaskStatus to,
    Future<void> Function() action,
  ) {
    if (!_canTransition(task.status, to)) {
      final prev = _tasks;
      emit(const TaskState.error(
          "That action isn't allowed for this task's current status."));
      emit(TaskState.loaded(prev));
      return Future.value();
    }
    return _mutate(action);
  }

  /// The allowed status flow:
  /// pending → started → completed → waitingReview → approved | rejected,
  /// with rejected → started so rejected work can be redone.
  static bool _canTransition(TaskStatus from, TaskStatus to) {
    switch (from) {
      case TaskStatus.pending:
        return to == TaskStatus.started;
      case TaskStatus.started:
        return to == TaskStatus.completed;
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
