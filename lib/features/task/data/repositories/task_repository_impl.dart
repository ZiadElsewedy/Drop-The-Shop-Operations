import 'dart:io';

import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/task/data/datasources/task_remote_datasource.dart';
import 'package:drop/features/task/data/models/task_model.dart';
import 'package:drop/features/task/data/models/task_template_model.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/task_ordering.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource _remote;

  TaskRepositoryImpl(this._remote);

  /// Maps models → entities, then orders newest-first (pending timestamps on top
  /// — see [sortTasksNewestFirst]).
  List<TaskEntity> _newestFirst(List<TaskModel> models) =>
      sortTasksNewestFirst(models.map((m) => m.toEntity()).toList());

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    try {
      return _newestFirst(await _remote.getAllTasks());
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<TaskEntity>> getTasksByBranch(String branchId) async {
    try {
      return _newestFirst(await _remote.getTasksByBranch(branchId));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<TaskEntity>> getEmployeeTasks(String employeeId) async {
    try {
      return _newestFirst(await _remote.getEmployeeTasks(employeeId));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<TaskEntity>> watchAllTasks() =>
      _remote.watchAllTasks().map(_newestFirst);

  @override
  Stream<List<TaskEntity>> watchTasksByBranch(String branchId) =>
      _remote.watchTasksByBranch(branchId).map(_newestFirst);

  @override
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId) =>
      _remote.watchEmployeeTasks(employeeId).map(_newestFirst);

  @override
  Future<TaskEntity?> getTask(String taskId) async {
    try {
      final model = await _remote.getTask(taskId);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskEntity> createTask(TaskEntity task) async {
    try {
      final created = await _remote.createTask(TaskModel.fromEntity(task));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateTask(TaskEntity task) async {
    try {
      await _remote.updateTask(TaskModel.fromEntity(task));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _remote.deleteTask(taskId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  }) async {
    try {
      await _remote.assignTask(
        taskId: taskId,
        employeeIds: employeeIds,
        assignedShiftId: assignedShiftId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskAttachment> uploadAttachment({
    required String taskId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) async {
    try {
      return await _remote.uploadAttachment(
        taskId: taskId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        onProgress: onProgress,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ─── Task templates ────────────────────────────────────────────
  // In-memory cache of the (tiny) template collection — read repeatedly when the
  // New-Task sheets open. Templates are global + change rarely, so a 20-minute
  // TTL + invalidate-on-write keeps the sheets off Firestore without staleness.
  static const _templatesTtl = Duration(minutes: 20);
  List<TaskTemplateEntity>? _cachedTemplates;
  DateTime? _templatesFetchedAt;

  bool get _templatesFresh =>
      _cachedTemplates != null &&
      _templatesFetchedAt != null &&
      DateTime.now().difference(_templatesFetchedAt!) < _templatesTtl;

  @override
  Future<List<TaskTemplateEntity>> getTemplates({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _templatesFresh) return _cachedTemplates!;
    try {
      final models = await _remote.getTemplates();
      final list = models.map((m) => m.toEntity()).toList();
      _cachedTemplates = list;
      _templatesFetchedAt = DateTime.now();
      return list;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  void _invalidateTemplates() {
    _cachedTemplates = null;
    _templatesFetchedAt = null;
  }

  @override
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template) async {
    try {
      final created =
          await _remote.createTemplate(TaskTemplateModel.fromEntity(template));
      _invalidateTemplates();
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _remote.deleteTemplate(templateId);
      _invalidateTemplates();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
