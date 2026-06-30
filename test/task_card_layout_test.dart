import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/widgets/task_card.dart';

/// Regression test for the Tasks screen crash: a [TaskCard] inside a scrolling
/// [ListView] (unbounded vertical constraints, exactly how the task screens use
/// it) must lay out without throwing a RenderBox/size assertion.
void main() {
  const user = UserEntity(
    uid: 'u1',
    email: 'ziad@drop.com',
    authProvider: 'password',
    displayName: 'Ziad Mohamed',
    role: UserRole.employee,
  );

  final task = TaskEntity(
    id: 't1',
    title: 'Inventory Audit',
    description: 'Check all inventory items and ensure quantities are accurate.',
    status: TaskStatus.started,
    priority: TaskPriority.high,
    assigneeIds: const ['u1'],
    deadline: DateTime(2026, 6, 18, 18),
    checklist: const [
      ChecklistItem(id: 'c1', title: 'Check shelf #1', completed: true),
      ChecklistItem(id: 'c2', title: 'Check shelf #2'),
      ChecklistItem(id: 'c3', title: 'Verify damaged items', isRequired: false),
    ],
  );

  testWidgets('TaskCard lays out inside a ListView without a layout assertion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [
              EntranceFade(
                child: TaskCard(
                  task: task,
                  directory: const {'u1': user},
                  branchName: 'Maadi Branch',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Inventory Audit'), findsOneWidget);
  });
}
