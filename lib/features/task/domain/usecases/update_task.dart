import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Updates a task (manager/admin full edit; employee limited fields per rules).
class UpdateTask {
  final TaskRepository _repository;
  const UpdateTask(this._repository);

  Future<void> call(TaskEntity task) => _repository.updateTask(task);
}
