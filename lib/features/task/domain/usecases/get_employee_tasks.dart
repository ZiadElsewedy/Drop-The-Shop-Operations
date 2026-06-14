import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Loads the tasks assigned to one employee (their own view).
class GetEmployeeTasks {
  final TaskRepository _repository;
  const GetEmployeeTasks(this._repository);

  Future<List<TaskEntity>> call(String employeeId) =>
      _repository.getEmployeeTasks(employeeId);
}
