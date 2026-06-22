import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:fbro/features/schedule/presentation/widgets/schedule_grid.dart';

UserEntity _member(String uid) =>
    UserEntity(uid: uid, email: '$uid@drop.test', authProvider: 'password');

WeeklyScheduleEntity _schedule(
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments) {
  // Any Sunday works; the grid only uses weekStart for the date headers.
  return WeeklyScheduleEntity(
    id: 'b1_2026-06-14',
    branchId: 'b1',
    weekStart: DateTime(2026, 6, 14),
    assignments: assignments,
  );
}

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows assigned count and excludes broken references',
      (tester) async {
    final members = [_member('u1'), _member('u2')];
    final schedule = _schedule({
      ScheduleDay.sunday: {
        // Two real members + one orphan uid that no longer maps to a member.
        ScheduleShift.morning: ['u1', 'u2', 'ghost'],
      },
    });

    await tester.pumpWidget(host(ScheduleGrid(
      schedule: schedule,
      members: members,
      onCellTap: (_, _) {},
    )));

    // The orphan is not counted → the cell reads "2" people, never "3".
    expect(find.text('2'), findsOneWidget);
    expect(find.text('people'), findsOneWidget);
    // The broken reference is flagged, never shown as a name/uid.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('ghost'), findsNothing);
    // No staffing target / quota is ever rendered.
    expect(find.textContaining('of '), findsNothing);
  });

  testWidgets('empty shifts read as Empty, not as a shortfall',
      (tester) async {
    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      onCellTap: (_, _) {},
    )));

    // 14 slots (7 days x 2 shifts), all empty.
    expect(find.text('Empty'), findsNWidgets(14));
  });

  testWidgets('tapping a cell reports its day and shift', (tester) async {
    ScheduleDay? tappedDay;
    ScheduleShift? tappedShift;

    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      onCellTap: (d, s) {
        tappedDay = d;
        tappedShift = s;
      },
    )));

    // First cell (Sunday morning) is the first "Empty" in document order.
    await tester.tap(find.text('Empty').first);
    await tester.pump();

    expect(tappedDay, ScheduleDay.sunday);
    expect(tappedShift, ScheduleShift.morning);
  });

  testWidgets('shift filter hides the other shift row', (tester) async {
    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      filter: ScheduleShift.night,
      onCellTap: (_, _) {},
    )));

    // Only the night row renders → 7 cells, not 14.
    expect(find.text('Empty'), findsNWidgets(7));
  });
}
