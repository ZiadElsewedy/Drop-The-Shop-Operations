import 'dart:io';
import 'package:fbro/core/enums/attachment_type.dart';
import 'package:fbro/features/task/domain/entities/task_attachment.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Uploads one media file (image / video) for a task and returns the resolved
/// [TaskAttachment] (id, download url, type, uploader, time).
class UploadTaskAttachment {
  final TaskRepository _repository;
  const UploadTaskAttachment(this._repository);

  Future<TaskAttachment> call({
    required String taskId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) =>
      _repository.uploadAttachment(
        taskId: taskId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        onProgress: onProgress,
      );
}
