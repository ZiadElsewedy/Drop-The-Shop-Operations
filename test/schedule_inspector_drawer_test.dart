import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/health/schedule_health_analyzer.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_inspector_drawer.dart';

/// Schedule V2 — the Mac inspector drawer. Extracted stateless, so it tests in
/// isolation: overview roster → tap a person → their week detail, no cubits.

UserEntity _user(String uid, String name, {String? position}) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      displayName: name,
      authProvider: 'password',
      branchId: 'b1',
      position: position,
    );

WeeklyScheduleEntity _sched(
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,
) =>
    WeeklyScheduleEntity(
      id: 'b1_2026-06-14',
      branchId: 'b1',
      weekStart: DateTime(2026, 6, 14),
      assignments: assignments,
    );

void main() {
  final schedule = _sched({
    ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
    ScheduleDay.monday: {ScheduleShift.morning: ['u1']},
  });
  final members = [_user('u1', 'Ziad Elsewedy', position: 'Cashier')];
  final insights = computeScheduleInsights(schedule, members);
  final report =
      const ScheduleHealthAnalyzer().analyze(schedule, members, nameOf: shortName);

  Future<void> pump(
    WidgetTester tester, {
    required String? selectedUid,
    required ValueChanged<String?> onSelect,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 900,
          child: ScheduleInspectorDrawer(
            schedule: schedule,
            members: members,
            report: report,
            insights: insights,
            selectedUid: selectedUid,
            onSelect: onSelect,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('overview shows week totals + a tappable team roster',
      (tester) async {
    final picked = <String?>[];
    await pump(tester, selectedUid: null, onSelect: picked.add);

    expect(find.text('THIS WEEK'), findsOneWidget);
    // Global schedule health moved out of the rail to the below-grid surface.
    expect(find.text('SCHEDULE HEALTH'), findsNothing);
    expect(find.text('TEAM · TAP FOR DETAIL'), findsOneWidget);
    // The roster row: short name + position.
    expect(find.text('Ziad E.'), findsOneWidget);
    expect(find.text('Cashier'), findsOneWidget);

    await tester.tap(find.text('Ziad E.'));
    await tester.pump();
    expect(picked, ['u1']);
  });

  testWidgets('selecting a person shows their week detail', (tester) async {
    await pump(tester, selectedUid: 'u1', onSelect: (_) {});

    // Header uses the full name; the detail lists the week facts.
    expect(find.text('Ziad Elsewedy'), findsOneWidget);
    expect(find.text('Weekly hours'), findsOneWidget);
    // Two 8h mornings → 16h; morning split 2.
    expect(find.text('16h'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('WEEK AT A GLANCE'), findsOneWidget);
  });

  testWidgets('the back control clears the selection', (tester) async {
    String? last = 'u1';
    await pump(tester, selectedUid: 'u1', onSelect: (u) => last = u);

    await tester.tap(find.text('Team'));
    await tester.pump();
    expect(last, isNull);
  });

  testWidgets('a stale selection (not in roster) falls back to the overview',
      (tester) async {
    await pump(tester, selectedUid: 'ghost', onSelect: (_) {});
    // Overview markers present; no employee-detail header.
    expect(find.text('TEAM · TAP FOR DETAIL'), findsOneWidget);
    expect(find.text('Weekly hours'), findsNothing);
  });
}
