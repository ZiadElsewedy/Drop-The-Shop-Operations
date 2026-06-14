import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Reviews a task — approve or reject, writing the audit fields + review note
/// (manager own-branch / admin).
class ReviewTask {
  final TaskRepository _repository;
  const ReviewTask(this._repository);

  Future<void> call({
    required String taskId,
    required bool approved,
    required String reviewerId,
    String? reviewNotes,
  }) =>
      _repository.reviewTask(
        taskId: taskId,
        approved: approved,
        reviewerId: reviewerId,
        reviewNotes: reviewNotes,
      );
}
