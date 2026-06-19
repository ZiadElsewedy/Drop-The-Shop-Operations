import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/task/data/models/task_model.dart';
import 'package:fbro/features/task/data/models/task_template_model.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> getAllTasks();
  Future<List<TaskModel>> getTasksByBranch(String branchId);
  Future<List<TaskModel>> getEmployeeTasks(String employeeId);

  /// Real-time variants — emit on every change so a newly assigned/updated task
  /// appears without a manual refresh (backed by Firestore's offline cache).
  Stream<List<TaskModel>> watchAllTasks();
  Stream<List<TaskModel>> watchTasksByBranch(String branchId);
  Stream<List<TaskModel>> watchEmployeeTasks(String employeeId);

  Future<TaskModel?> getTask(String taskId);
  Future<TaskModel> createTask(TaskModel task);
  Future<void> updateTask(TaskModel task);
  Future<void> deleteTask(String taskId);
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  });
  Future<String> uploadProof(String taskId, File file);

  // ─── Task templates (reusable blueprints) ──────────────────────
  Future<List<TaskTemplateModel>> getTemplates();
  Future<TaskTemplateModel> createTemplate(TaskTemplateModel template);
  Future<void> deleteTemplate(String templateId);
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  TaskRemoteDataSourceImpl(this._firestore, this._storage);

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection(AppConstants.tasksCollection);

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection(AppConstants.taskTemplatesCollection);

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
      // Multi-assignee (Phase 9): a task belongs to an employee if their uid is
      // in the `assigneeIds` array.
      final snap =
          await _tasks.where('assigneeIds', arrayContains: employeeId).get();
      return snap.docs
          .map((d) => TaskModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load your tasks.');
    }
  }

  List<TaskModel> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => TaskModel.fromMap(d.data(), id: d.id)).toList();

  @override
  Stream<List<TaskModel>> watchAllTasks() =>
      _tasks.snapshots().map(_mapSnap);

  @override
  Stream<List<TaskModel>> watchTasksByBranch(String branchId) =>
      _tasks.where('branchId', isEqualTo: branchId).snapshots().map(_mapSnap);

  @override
  Stream<List<TaskModel>> watchEmployeeTasks(String employeeId) => _tasks
      .where('assigneeIds', arrayContains: employeeId)
      .snapshots()
      .map(_mapSnap);

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
    required List<String> employeeIds,
    String? assignedShiftId,
  }) async {
    try {
      await _tasks.doc(taskId).set({
        'assigneeIds': employeeIds,
        // Keep the legacy primary-assignee mirror in sync (rules / statistics).
        'assignedEmployeeId': employeeIds.isEmpty ? null : employeeIds.first,
        // Only touch the shift link when one is supplied (merge preserves it).
        'assignedShiftId': ?assignedShiftId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to assign task.');
    }
  }

  /// Hard ceiling so a misconfigured/disabled Storage bucket or a dropped
  /// connection fails cleanly instead of hanging the submit flow indefinitely.
  static const _uploadTimeout = Duration(seconds: 60);

  @override
  Future<String> uploadProof(String taskId, File file) async {
    try {
      // Fixed path → re-uploading overwrites the previous proof. Firebase issues
      // a fresh download token on overwrite, so the saved URL changes.
      final ref =
          _storage.ref('${AppConstants.tasksCollection}/$taskId/proof.jpg');
      final upload =
          ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await upload.timeout(
        _uploadTimeout,
        onTimeout: () {
          upload.cancel();
          throw const ServerException(
              'Photo upload timed out. Check your connection and try again.');
        },
      );
      return await snapshot.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ServerException(
          'Photo upload timed out. Check your connection and try again.');
    } on FirebaseException catch (e) {
      throw ServerException(_storageError(e));
    }
  }

  /// Translates a Storage [FirebaseException] into an actionable message.
  ///
  /// The previous implementation blamed *every* failure on the network, which
  /// masked the real cause: an `unauthorized` / `object-not-found` error almost
  /// always means the Storage rules aren't deployed or the bucket isn't enabled
  /// — not a bad connection. Surfacing the real code is what makes the proof
  /// pipeline diagnosable in the field.
  static String _storageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'unauthenticated':
        return 'Photo upload was blocked by Storage permissions (${e.code}). '
            'Firebase Storage rules likely need to be deployed.';
      case 'object-not-found':
      case 'bucket-not-found':
      case 'project-not-found':
        return 'Firebase Storage isn\'t set up for this project (${e.code}). '
            'Enable Storage in the Firebase console, then retry.';
      case 'retry-limit-exceeded':
      case 'canceled':
        return 'Photo upload failed — check your connection and try again.';
      default:
        return e.message ?? 'Photo upload failed (${e.code}).';
    }
  }

  // ─── Task templates ────────────────────────────────────────────
  @override
  Future<List<TaskTemplateModel>> getTemplates() async {
    try {
      // Single-field order (auto-indexed). Branch scoping is applied
      // client-side in the cubit — template volume is tiny.
      final snap = await _templates.orderBy('title').get();
      return snap.docs
          .map((d) => TaskTemplateModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load task templates.');
    }
  }

  @override
  Future<TaskTemplateModel> createTemplate(TaskTemplateModel template) async {
    try {
      final docRef = _templates.doc();
      final created = template.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save task template.');
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _templates.doc(templateId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete task template.');
    }
  }
}
