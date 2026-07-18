import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
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
import 'package:drop/features/task/presentation/widgets/recurring_shift_task_sheets.dart';

void main() {
  test(
    'recurring-template save does not wait for today-instance follow-up I/O',
    () async {
      final repository = _TaskRepository();
      final cubit = _createCubit(repository);
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

  testWidgets('Automation Center empty state stays usable on a phone', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final repository = _TaskRepository();
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await _openAutomationCenter(tester, cubit);

    expect(find.text('Automation Center'), findsOneWidget);
    expect(
      find.text('Manage recurring shift routines for this branch.'),
      findsOneWidget,
    );
    expect(find.text('Automate repetitive branch tasks.'), findsOneWidget);
    expect(find.text('Create Automation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Create Automation'));
    await tester.pumpAndSettle();

    expect(find.text('New Automation'), findsOneWidget);
    expect(find.text('Create Automation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Automation Center distinguishes load failure from empty', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final repository = _TaskRepository(recurringError: StateError('offline'));
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await _openAutomationCenter(tester, cubit);

    expect(
      find.text('Automation details could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('Automate repetitive branch tasks.'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich automation card exposes truthful operational details', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final nextRun = DateTime.now().add(const Duration(days: 2, hours: 1));
    final lastRun = DateTime.now().subtract(const Duration(hours: 2));
    final repository = _TaskRepository(
      templates: [
        RecurringTaskTemplateEntity(
          id: 'open-shift',
          title: 'Open Shift Checklist',
          branchId: 'branch-1',
          shift: ScheduleShift.morning,
          repeat: TemplateRepeatMode.daily,
          nextRunAt: nextRun,
          lastRunAt: lastRun,
          lastStatus: 'completed',
          lastGeneratedTaskId: 'task-42',
        ),
      ],
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await _openAutomationCenter(tester, cubit);

    expect(find.text('Active'), findsWidgets);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Morning shift'), findsOneWidget);
    expect(find.text('Next automation check'), findsOneWidget);
    expect(find.text('NEXT AUTOMATION CHECK'), findsOneWidget);
    expect(
      find.textContaining(AppDateFormatter.time(nextRun.toLocal())),
      findsWidgets,
    );

    await tester.ensureVisible(find.text('Generated successfully'));
    await tester.pumpAndSettle();

    expect(find.text('SHIFT WINDOW'), findsOneWidget);
    expect(
      find.text('Exact start and end are not available yet.'),
      findsOneWidget,
    );
    expect(find.text('Missed policy · Not enabled'), findsOneWidget);
    expect(find.text('Generated successfully'), findsOneWidget);
    expect(find.text('Last task'), findsOneWidget);
    expect(find.text('Tap to open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'paused and failed routines keep distinct status and outcome labels',
    (tester) async {
      await _usePhoneViewport(tester);
      final repository = _TaskRepository(
        templates: [
          const RecurringTaskTemplateEntity(
            id: 'paused',
            title: 'Paused routine',
            branchId: 'branch-1',
            shift: ScheduleShift.night,
            repeat: TemplateRepeatMode.weekly,
            weekday: DateTime.friday,
            active: false,
            lastStatus: 'failed',
            failureCount: 2,
          ),
          const RecurringTaskTemplateEntity(
            id: 'failed',
            title: 'Failed routine',
            branchId: 'branch-1',
            shift: ScheduleShift.morning,
            repeat: TemplateRepeatMode.daily,
            lastStatus: 'failed',
            failureCount: 1,
          ),
        ],
      );
      final cubit = _createCubit(repository);
      addTearDown(cubit.close);

      await _openAutomationCenter(tester, cubit);

      expect(find.text('Paused'), findsWidgets);
      expect(find.text('Every Friday'), findsOneWidget);
      await tester.ensureVisible(find.text('Last generation failed').first);
      await tester.pumpAndSettle();
      expect(find.text('Last generation failed'), findsWidgets);

      await tester.fling(find.byType(ListView), const Offset(0, -1200), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Error'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('toggle delete and last-task link reuse the existing behavior', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final repository = _TaskRepository(
      templates: [
        RecurringTaskTemplateEntity(
          id: 'routine-1',
          title: 'Opening Checklist',
          branchId: 'branch-1',
          shift: ScheduleShift.morning,
          lastRunAt: DateTime.now(),
          lastStatus: 'completed',
          lastGeneratedTaskId: 'generated-7',
        ),
      ],
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => _AutomationLauncher(cubit: cubit),
        ),
        GoRoute(
          path: RouteNames.taskDetailPattern,
          builder: (_, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['taskId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.tap(find.text('Open automation'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('automation-toggle-routine-1')));
    await tester.pumpAndSettle();
    expect(repository.lastUpdated?.active, isFalse);

    await tester.ensureVisible(
      find.byKey(const ValueKey('automation-last-task-routine-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('automation-last-task-routine-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opened generated-7'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open automation'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('automation-delete-routine-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automation-delete-routine-1')));
    await tester.pumpAndSettle();

    expect(repository.lastDeletedId, 'routine-1');
    expect(tester.takeException(), isNull);
  });
}

TaskCubit _createCubit(_TaskRepository repository) => TaskCubit(
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

Future<void> _usePhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openAutomationCenter(WidgetTester tester, TaskCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: _AutomationLauncher(cubit: cubit),
    ),
  );
  await tester.tap(find.text('Open automation'));
  await tester.pumpAndSettle();
}

class _AutomationLauncher extends StatelessWidget {
  const _AutomationLauncher({required this.cubit});

  final TaskCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showManageRecurringShiftTasksSheet(
            context: context,
            cubit: cubit,
            branchId: 'branch-1',
          ),
          child: const Text('Open automation'),
        ),
      ),
    );
  }
}

class _TaskRepository implements TaskRepository {
  _TaskRepository({
    List<RecurringTaskTemplateEntity> templates = const [],
    this.recurringError,
  }) : templates = [...templates];

  final Completer<TaskEntity?> instanceWrite = Completer<TaskEntity?>();
  final List<RecurringTaskTemplateEntity> templates;
  final Object? recurringError;
  RecurringTaskTemplateEntity? lastUpdated;
  String? lastDeletedId;

  @override
  Future<List<RecurringTaskTemplateEntity>> getRecurringTemplates(
    String branchId,
  ) async {
    if (recurringError case final error?) throw error;
    return List.unmodifiable(
      templates.where((template) => template.branchId == branchId),
    );
  }

  @override
  Future<RecurringTaskTemplateEntity> createRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async => template.copyWith(id: 'template-1');

  @override
  Future<TaskEntity?> createTaskWithId(TaskEntity task) => instanceWrite.future;

  @override
  Future<void> updateRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async {
    lastUpdated = template;
    final index = templates.indexWhere((item) => item.id == template.id);
    if (index >= 0) templates[index] = template;
  }

  @override
  Future<void> deleteRecurringTemplate(String templateId) async {
    lastDeletedId = templateId;
    templates.removeWhere((template) => template.id == templateId);
  }

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
