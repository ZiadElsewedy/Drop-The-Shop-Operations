import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/health/schedule_health_analyzer.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_overview_surface.dart';

/// Schedule V2 layout rebalance — the below-grid overview surface (Health +
/// Insights + Legend). Presentation only; reads the frozen analyzer's report.

UserEntity _member(String uid, String name) => UserEntity(
    uid: uid,
    email: '$uid@drop.test',
    displayName: name,
    authProvider: 'password');

WeeklyScheduleEntity _schedule(
        Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments) =>
    WeeklyScheduleEntity(
      id: 'b1_2026-06-14',
      branchId: 'b1',
      weekStart: DateTime(2026, 6, 14),
      assignments: assignments,
    );

void main() {
  final ahmed = _member('u1', 'Ahmed Maher');

  Future<void> pump(
    WidgetTester tester,
    WeeklyScheduleEntity schedule,
  ) async {
    // A desktop-width window so the wide three-column layout has room.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final members = [ahmed];
    final report = const ScheduleHealthAnalyzer().analyze(schedule, members);
    final insights = computeScheduleInsights(schedule, members);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          child: SingleChildScrollView(
            child: ScheduleOverviewSurface(report: report, insights: insights),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lays out health · insights · legend with a prominent score',
      (tester) async {
    // M·N·M·N·M — a Fair week (score 74) with rest findings.
    await pump(
      tester,
      _schedule({
        ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.monday: {ScheduleShift.night: ['u1']},
        ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.wednesday: {ScheduleShift.night: ['u1']},
        ScheduleDay.thursday: {ScheduleShift.morning: ['u1']},
      }),
    );

    // Three cards.
    expect(find.text('SCHEDULE HEALTH'), findsOneWidget);
    expect(find.text('INSIGHTS'), findsOneWidget);
    expect(find.text('LEGEND'), findsOneWidget);
    // Prominent score (the big 36px number, not the small per-category scores).
    expect(
      find.byWidgetPredicate(
          (w) => w is Text && w.data == '74' && (w.style?.fontSize ?? 0) >= 30),
      findsOneWidget,
    );
    expect(find.text(' /100'), findsOneWidget);
    expect(find.text('Fair'), findsOneWidget);
    // A one-line finding.
    expect(find.text('TOP FINDINGS'), findsOneWidget);
    expect(find.textContaining('right after a night'), findsOneWidget);
    // The legend is collapsed by default (near-invisible) — its shift-hour
    // keys aren't rendered until it's expanded.
    expect(find.text('Morning'), findsNothing);
    expect(find.text('Night'), findsNothing);
  });

  testWidgets('the legend stays collapsed until expanded', (tester) async {
    await pump(
      tester,
      _schedule({
        ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.monday: {ScheduleShift.morning: ['u1']},
      }),
    );

    // Collapsed: only the quiet label shows, not the shift-hour keys.
    expect(find.text('LEGEND'), findsOneWidget);
    expect(find.text('Morning'), findsNothing);
    expect(find.text('Night'), findsNothing);

    // Tapping the legend reveals the keys.
    await tester.tap(find.text('LEGEND'));
    await tester.pumpAndSettle();
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
  });

  testWidgets('a finding reveals its fix only after interaction',
      (tester) async {
    await pump(
      tester,
      _schedule({
        ScheduleDay.monday: {ScheduleShift.night: ['u1']},
        ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
      }),
    );

    // Collapsed: the one-liner shows, the explanation (suggestion) does not.
    expect(find.textContaining('right after a night'), findsOneWidget);
    expect(find.textContaining('Leave a day off'), findsNothing);
    expect(find.text('View'), findsWidgets);

    // Tap the finding → its suggestion appears inline.
    await tester.tap(find.textContaining('right after a night'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leave a day off'), findsOneWidget);
  });

  testWidgets('tapping a category filters the findings', (tester) async {
    await pump(
      tester,
      _schedule({
        ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.monday: {ScheduleShift.night: ['u1']},
        ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.wednesday: {ScheduleShift.night: ['u1']},
        ScheduleDay.thursday: {ScheduleShift.morning: ['u1']},
      }),
    );
    // The five-lens breakdown is present; Rest carries the findings.
    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);
    await tester.tap(find.text('Rest'));
    await tester.pumpAndSettle();
    // Header switches to the focused lens; the rest finding stays visible.
    expect(find.text('REST'), findsOneWidget);
    expect(find.textContaining('right after a night'), findsOneWidget);
  });

  testWidgets('a healthy week reads calm — no findings', (tester) async {
    // M·M·M·off·N·N·N — the canonical healthy shape.
    await pump(
      tester,
      _schedule({
        ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.monday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
        ScheduleDay.thursday: {ScheduleShift.night: ['u1']},
        ScheduleDay.friday: {ScheduleShift.night: ['u1']},
        ScheduleDay.saturday: {ScheduleShift.night: ['u1']},
      }),
    );
    expect(
      find.byWidgetPredicate(
          (w) => w is Text && w.data == '100' && (w.style?.fontSize ?? 0) >= 30),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing to flag'), findsOneWidget);
    expect(find.text('TOP FINDINGS'), findsNothing);
  });
}
