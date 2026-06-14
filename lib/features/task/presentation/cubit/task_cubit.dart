import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/task_priority.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/enums/task_type.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/usecases/assign_task.dart';
import 'package:fbro/features/task/domain/usecases/change_task_status.dart';
import 'package:fbro/features/task/domain/usecases/create_task.dart';
import 'package:fbro/features/task/domain/usecases/delete_task.dart';
import 'package:fbro/features/task/domain/usecases/get_all_tasks.dart';
import 'package:fbro/features/task/domain/usecases/get_employee_tasks.dart';
import 'package:fbro/features/task/domain/usecases/get_tasks_by_branch.dart';
import 'package:fbro/features/task/domain/usecases/review_task.dart';
import 'package:fbro/features/task/domain/usecases/update_task.dart';
import 'package:fbro/features/task/domain/usecases/upload_task_proof.dart';
import 'task_state.dart';

/// Drives the task workflow for all three roles. The list loaded depends on the
/// signed-in user's role (admin: all · manager: own branch · employee: own
/// tasks). Workflow transitions are validated here ([_canTransition]); the
/// branch/role write rules are enforced server-side in `firestore.rules`.
class TaskCubit extends Cubit<TaskState> {
  final GetAllTasks _getAllTasks;
  final GetTasksByBranch _getTasksByBranch;
  final GetEmployeeTasks _getEmployeeTasks;
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final AssignTask _assignTask;
  final ChangeTaskStatus _changeTaskStatus;
  final ReviewTask _reviewTask;
  final UploadTaskProof _uploadTaskProof;
  final GetUsersByBranch _getUsersByBranch;

  /// The user whose view is currently loaded — used to refresh after mutations.
  UserEntity? _user;

  TaskCubit({
    required this._getAllTasks,
    required this._getTasksByBranch,
    required this._getEmployeeTasks,
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

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  /// Loads the task list for [user] by role and remembers it for refreshes.
  Future<void> load(UserEntity user) async {
    _user = user;
    emit(const TaskState.loading());
    try {
      emit(TaskState.loaded(await _fetchFor(user)));
    } on Failure catch (e) {
      emit(TaskState.error(e.message));
    } catch (_) {
      emit(const TaskState.error('Failed to load tasks. Please try again.'));
    }
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user);
  }

  Future<List<TaskEntity>> _fetchFor(UserEntity user) {
    if (user.role.isAdmin) return _getAllTasks();
    if (user.role.isManager) return _getTasksByBranch(user.branchId ?? '');
    return _getEmployeeTasks(user.uid);
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

  // ─── Assignee picker support ───────────────────────────────────
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

  // ─── Internals ─────────────────────────────────────────────────
  /// Runs [action], then refreshes the list — keeping the current list visible
  /// (busy) so the UI never flickers, and restoring it on failure.
  Future<void> _mutate(Future<void> Function() action) async {
    final user = _user;
    if (user == null || _busy) return;
    final prev = _tasks;
    emit(TaskState.loaded(prev, busy: true));
    try {
      await action();
      emit(TaskState.loaded(await _fetchFor(user)));
    } on Failure catch (e) {
      emit(TaskState.error(e.message));
      emit(TaskState.loaded(prev));
    } catch (_) {
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
}
