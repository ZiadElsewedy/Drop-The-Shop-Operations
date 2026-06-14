import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Loads every task (admin / global view).
class GetAllTasks {
  final TaskRepository _repository;
  const GetAllTasks(this._repository);

  Future<List<TaskEntity>> call() => _repository.getAllTasks();
}
