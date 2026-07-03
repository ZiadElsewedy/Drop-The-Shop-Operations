import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 1000, child: child),
        ),
      );

  testWidgets('renders status label, title, branch and due', (tester) async {
    await tester.pumpWidget(host(TaskFeedRow(
      task: TaskEntity(
        id: '1',
        title: 'Open the shop',
        status: TaskStatus.started,
        deadline: DateTime(2099, 6, 28), // future → not overdue, plain label
      ),
      branchName: 'Arkan',
    )));

    expect(find.text('Open the shop'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Arkan'), findsOneWidget);
    expect(find.text('28 Jun'), findsOneWidget);
  });

  testWidgets('an overdue task marks the due label late', (tester) async {
    await tester.pumpWidget(host(TaskFeedRow(
      task: TaskEntity(
        id: '1',
        title: 'Late task',
        status: TaskStatus.started,
        deadline: DateTime(2020, 1, 1), // safely in the past
      ),
    )));
    expect(find.text('1 Jan · late'), findsOneWidget);
  });

  testWidgets('shows the single assignee name', (tester) async {
    await tester.pumpWidget(host(TaskFeedRow(
      task: const TaskEntity(id: '1', title: 't', assigneeIds: ['u1']),
      directory: const {
        'u1': UserEntity(
            uid: 'u1', email: 'z@x.co', authProvider: 'password', displayName: 'Ziad'),
      },
    )));
    expect(find.text('Ziad'), findsOneWidget);
  });

  testWidgets('tapping fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(TaskFeedRow(
      task: const TaskEntity(id: '1', title: 't'),
      onTap: () => tapped = true,
    )));
    await tester.tap(find.byType(TaskFeedRow));
    expect(tapped, isTrue);
  });

  testWidgets('renders a checklist progress track when present', (tester) async {
    await tester.pumpWidget(host(TaskFeedRow(
      task: const TaskEntity(
        id: '1',
        title: 't',
        checklist: [
          ChecklistItem(id: 'a', title: 'one', completed: true),
          ChecklistItem(id: 'b', title: 'two'),
        ],
      ),
    )));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
