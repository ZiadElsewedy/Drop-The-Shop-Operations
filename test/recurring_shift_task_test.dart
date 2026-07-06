import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';

void main() {
  test(
    'recurring-template save does not wait for today-instance follow-up I/O',
    () async {
      final repository = _TaskRepository();
      final cubit = TaskCubit(
        repository: repository,
        branchRepository: _BranchRepository(),
        scheduleRepository: _ScheduleRepository(),
        createTask: CreateTask(repository),
        updateTask: UpdateTask(repository),
        deleteTask: DeleteTask(repository),
        assignTask: AssignTask(repository),
        uploadTaskAttachment: UploadTaskAttachment(repository),
        getUsersByBranch: GetUsersByBranch(_AuthRepository()),
        notifyTaskEvent: NotifyTaskEvent(_NotificationRepository()),
      );
      addTearDown(cubit.close);

      await cubit
          .createRecurringShiftTemplate(
            title: 'Open Store',
            priority: TaskPriority.normal,
            branchId: 'branch-1',
            shift: ScheduleShift.morning,
            repeat: TemplateRepeatMode.daily,
          )
          .timeout(const Duration(milliseconds: 200));

      expect(
        repository.instanceWrite.isCompleted,
        isFalse,
        reason: 'the best-effort instance write is still pending',
      );

      repository.instanceWrite.complete(null);
      await Future<void>.delayed(Duration.zero);
    },
  );
}

class _TaskRepository implements TaskRepository {
  final Completer<TaskEntity?> instanceWrite = Completer<TaskEntity?>();

  @override
  Future<RecurringTaskTemplateEntity> createRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async => template.copyWith(id: 'template-1');

  @override
  Future<TaskEntity?> createTaskWithId(TaskEntity task) => instanceWrite.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BranchRepository implements BranchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduleRepository implements ScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NotificationRepository implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
