import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:drop/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/work_type_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Render-only — the cubit is touched lazily on tap, so a [Fake] suffices.
class _FakeTaskCubit extends Fake implements TaskCubit {}

Widget _host({
  required TaskEntity task,
  bool interactive = false,
  bool showReviewHint = false,
}) =>
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: WorkTypePanel(
              task: task,
              cubit: _FakeTaskCubit(),
              interactive: interactive,
              showReviewHint: showReviewHint,
            ),
          ),
        ),
      ),
    );

void main() {
  test('hasContentFor is false for a general task', () {
    expect(
      WorkTypePanel.hasContentFor(const TaskEntity(id: 't', title: 'x')),
      isFalse,
    );
    expect(
      WorkTypePanel.hasContentFor(
          const TaskEntity(id: 't', title: 'x', workType: 'transfer')),
      isTrue,
    );
  });

  testWidgets('inspection: renders points + pass/warn/fail + result summary',
      (tester) async {
    final task = TaskEntity(
      id: 'i1',
      title: 'Morning inspection',
      workType: 'inspection',
      status: TaskStatus.started,
      checklist: const [
        ChecklistItem(id: 'p1', title: 'Floor clean'),
        ChecklistItem(id: 'p2', title: 'Fridge temp'),
      ],
      data: const {
        InventoryCountWorkType.kArea: null, // ignore
        'results': {'p1': 'pass', 'p2': 'fail'},
      },
    );
    await tester.pumpWidget(_host(task: task, interactive: true));

    expect(find.text('INSPECTION POINTS'), findsOneWidget);
    expect(find.text('Floor clean'), findsOneWidget);
    expect(find.text('Fridge temp'), findsOneWidget);
    // Three result chips per point.
    expect(find.text('Pass'), findsNWidgets(2));
    expect(find.text('Fail'), findsNWidgets(2));
    // Summary reflects the marked results.
    expect(find.text('1 pass · 0 warning · 1 fail'), findsOneWidget);
  });

  testWidgets('transfer: summary + milestone spine + next-step log button',
      (tester) async {
    final task = TaskEntity(
      id: 'tr1',
      title: 'Move stock',
      workType: 'transfer',
      status: TaskStatus.started,
      data: const {
        TransferWorkType.kGoods: 'Jackets',
        TransferWorkType.kDestination: 'Downtown',
      },
    );
    await tester.pumpWidget(_host(task: task, interactive: true));

    expect(find.text('Jackets → Downtown'), findsOneWidget); // summary
    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.text('Dispatched'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    // Setup context is shown read-only.
    expect(find.text('Goods'), findsOneWidget);
    // The next pending milestone (only) offers a log action.
    expect(find.text('Log'), findsOneWidget);
  });

  testWidgets('manager view of a reconciled count shows the fast-path hint',
      (tester) async {
    final task = TaskEntity(
      id: 'inv1',
      title: 'Count stock',
      workType: 'inventoryCount',
      status: TaskStatus.waitingReview,
      data: const {
        InventoryCountWorkType.kArea: 'Stockroom',
        InventoryCountWorkType.kExpectedQty: 20,
        InventoryCountWorkType.kCountedQty: 20,
      },
    );
    await tester.pumpWidget(_host(task: task, showReviewHint: true));

    expect(find.text('Auto-approvable'), findsOneWidget);
    // Completion values are shown read-only (not an editable form) for a viewer.
    expect(find.text('RECORDED'), findsOneWidget);
  });
}
