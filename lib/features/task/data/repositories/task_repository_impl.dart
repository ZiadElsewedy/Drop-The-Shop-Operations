import 'dart:io';

import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/task/data/datasources/task_remote_datasource.dart';
import 'package:fbro/features/task/data/models/task_model.dart';
import 'package:fbro/features/task/data/models/task_template_model.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/entities/task_template_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource _remote;

  TaskRepositoryImpl(this._remote);

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    try {
      final models = await _remote.getAllTasks();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<TaskEntity>> getTasksByBranch(String branchId) async {
    try {
      final models = await _remote.getTasksByBranch(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<TaskEntity>> getEmployeeTasks(String employeeId) async {
    try {
      final models = await _remote.getEmployeeTasks(employeeId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<TaskEntity>> watchAllTasks() =>
      _remote.watchAllTasks().map((l) => l.map((m) => m.toEntity()).toList());

  @override
  Stream<List<TaskEntity>> watchTasksByBranch(String branchId) => _remote
      .watchTasksByBranch(branchId)
      .map((l) => l.map((m) => m.toEntity()).toList());

  @override
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId) => _remote
      .watchEmployeeTasks(employeeId)
      .map((l) => l.map((m) => m.toEntity()).toList());

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
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
  }) async {
    try {
      await _remote.updateStatus(taskId: taskId, status: status);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> reviewTask({
    required String taskId,
    required bool approved,
    required String reviewerId,
    String? reviewNotes,
  }) async {
    try {
      await _remote.reviewTask(
        taskId: taskId,
        approved: approved,
        reviewerId: reviewerId,
        reviewNotes: reviewNotes,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<String> uploadProof(String taskId, File file) async {
    try {
      return await _remote.uploadProof(taskId, file);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ─── Task templates ────────────────────────────────────────────
  @override
  Future<List<TaskTemplateEntity>> getTemplates() async {
    try {
      final models = await _remote.getTemplates();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template) async {
    try {
      final created =
          await _remote.createTemplate(TaskTemplateModel.fromEntity(template));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _remote.deleteTemplate(templateId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
