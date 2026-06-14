import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/task/data/models/task_model.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> getAllTasks();
  Future<List<TaskModel>> getTasksByBranch(String branchId);
  Future<List<TaskModel>> getEmployeeTasks(String employeeId);
  Future<TaskModel?> getTask(String taskId);
  Future<TaskModel> createTask(TaskModel task);
  Future<void> updateTask(TaskModel task);
  Future<void> deleteTask(String taskId);
  Future<void> assignTask({
    required String taskId,
    required String? employeeId,
    String? assignedShiftId,
  });
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
  });
  Future<void> reviewTask({
    required String taskId,
    required bool approved,
    required String reviewerId,
    String? reviewNotes,
  });
  Future<String> uploadProof(String taskId, File file);
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  TaskRemoteDataSourceImpl(this._firestore, this._storage);

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection(AppConstants.tasksCollection);

  @override
  Future<List<TaskModel>> getAllTasks() async {
    try {
      final snap = await _tasks.get();
      return snap.docs
          .map((d) => TaskModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load tasks.');
    }
  }

  @override
  Future<List<TaskModel>> getTasksByBranch(String branchId) async {
    try {
      final snap = await _tasks.where('branchId', isEqualTo: branchId).get();
      return snap.docs
          .map((d) => TaskModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load branch tasks.');
    }
  }

  @override
  Future<List<TaskModel>> getEmployeeTasks(String employeeId) async {
    try {
      final snap =
          await _tasks.where('assignedEmployeeId', isEqualTo: employeeId).get();
      return snap.docs
          .map((d) => TaskModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load your tasks.');
    }
  }

  @override
  Future<TaskModel?> getTask(String taskId) async {
    try {
      final doc = await _tasks.doc(taskId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TaskModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load task.');
    }
  }

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    try {
      final docRef = _tasks.doc();
      final created = task.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create task.');
    }
  }

  @override
  Future<void> updateTask(TaskModel task) async {
    try {
      await _tasks.doc(task.id).set({
        ...task.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update task.');
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _tasks.doc(taskId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete task.');
    }
  }

  @override
  Future<void> assignTask({
    required String taskId,
    required String? employeeId,
    String? assignedShiftId,
  }) async {
    try {
      await _tasks.doc(taskId).set({
        'assignedEmployeeId': employeeId,
        // Only touch the shift link when one is supplied (merge preserves it).
        'assignedShiftId': ?assignedShiftId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to assign task.');
    }
  }

  @override
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
  }) async {
    try {
      await _tasks.doc(taskId).set({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update task status.');
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
      await _tasks.doc(taskId).set({
        'status':
            (approved ? TaskStatus.approved : TaskStatus.rejected).value,
        if (approved) ...{
          'approvedBy': reviewerId,
          'approvedAt': FieldValue.serverTimestamp(),
        } else ...{
          'rejectedBy': reviewerId,
          'rejectedAt': FieldValue.serverTimestamp(),
        },
        'reviewNotes': ?reviewNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to review task.');
    }
  }

  @override
  Future<String> uploadProof(String taskId, File file) async {
    try {
      // Fixed path → re-uploading overwrites the previous proof. Firebase issues
      // a fresh download token on overwrite, so the saved URL changes.
      final ref = _storage.ref('${AppConstants.tasksCollection}/$taskId/proof.jpg');
      final snapshot = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Proof upload failed. Please try again.');
    }
  }
}
