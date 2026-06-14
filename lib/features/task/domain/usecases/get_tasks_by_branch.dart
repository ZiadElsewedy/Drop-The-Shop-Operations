import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Loads tasks for one branch (manager / admin).
class GetTasksByBranch {
  final TaskRepository _repository;
  const GetTasksByBranch(this._repository);

  Future<List<TaskEntity>> call(String branchId) =>
      _repository.getTasksByBranch(branchId);
}
