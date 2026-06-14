import 'dart:io';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Uploads a proof image for a task and returns its download URL.
class UploadTaskProof {
  final TaskRepository _repository;
  const UploadTaskProof(this._repository);

  Future<String> call(String taskId, File file) =>
      _repository.uploadProof(taskId, file);
}
