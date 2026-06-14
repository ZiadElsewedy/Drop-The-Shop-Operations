import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Moves a task to a new [TaskStatus] (employee start / complete / submit).
class ChangeTaskStatus {
  final TaskRepository _repository;
  const ChangeTaskStatus(this._repository);

  Future<void> call({required String taskId, required TaskStatus status}) =>
      _repository.updateStatus(taskId: taskId, status: status);
}
