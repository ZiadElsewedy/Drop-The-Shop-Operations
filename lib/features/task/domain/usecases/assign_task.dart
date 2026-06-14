import 'package:fbro/features/task/domain/repositories/task_repository.dart';

/// Assigns an employee (and optionally a shift) to a task; null unassigns.
class AssignTask {
  final TaskRepository _repository;
  const AssignTask(this._repository);

  Future<void> call({
    required String taskId,
    required String? employeeId,
    String? assignedShiftId,
  }) =>
      _repository.assignTask(
        taskId: taskId,
        employeeId: employeeId,
        assignedShiftId: assignedShiftId,
      );
}
