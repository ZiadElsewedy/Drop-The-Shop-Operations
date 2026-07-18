import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_analytics.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_filters.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_summary.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_record_card.dart';

AttendanceEntity _rec({
  required DateTime date,
  AttendanceStatus status = AttendanceStatus.completed,
  int worked = 480,
  int late = 0,
  int overtime = 0,
  DateTime? clockIn,
  DateTime? clockOut,
}) =>
    AttendanceEntity(
      id: date.toIso8601String(),
      userId: 'u1',
      userName: 'Alice',
      shift: ScheduleShift.morning,
      date: date,
      status: status,
      clockIn: clockIn,
      clockOut: clockOut,
      workedMinutes: worked,
      lateMinutes: late,
      overtimeMinutes: overtime,
    );

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  // Mirrors the History screen's `_Loaded` body (summary + filters + cards in a
  // plain ListView) — the render path that must not throw.
  testWidgets('history body renders summary, filters and cards without throwing',
      (tester) async {
    final now = DateTime(2026, 7, 17);
    final records = [
      _rec(
        date: DateTime(2026, 7, 15),
        clockIn: DateTime(2026, 7, 15, 8, 35),
        clockOut: DateTime(2026, 7, 15, 16, 40),
        late: 5,
      ),
      _rec(date: DateTime(2026, 7, 12), status: AttendanceStatus.absent, worked: 0),
      _rec(
        date: DateTime(2026, 7, 10),
        clockIn: DateTime(2026, 7, 10, 8, 30),
        clockOut: DateTime(2026, 7, 10, 17, 10),
        overtime: 40,
      ),
    ];
    final stats = AttendanceStats.from(records, asOf: now);

    await tester.pumpWidget(host(ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AttendanceHistorySummary(stats: stats),
        const SizedBox(height: 16),
        AttendanceHistoryFilters(
          query: const AttendanceHistoryQuery(),
          onRange: (_, {start, end}) {},
          onStatus: (_) {},
          onToggleShift: (_) {},
        ),
        const SizedBox(height: 16),
        for (final r in records) AttendanceRecordCard(record: r),
      ],
    )));
    await tester.pump(const Duration(seconds: 1)); // settle the count-up

    expect(tester.takeException(), isNull);
    expect(find.text('Present'), findsOneWidget); // summary label
    expect(find.text('On time'), findsWidgets); // a status filter chip
    expect(find.text('Alice'), findsNothing); // self cards lead with the date

    await tester.pumpWidget(const SizedBox()); // unmount cleanly
  });

  testWidgets('empty-facet list still renders (no records)', (tester) async {
    await tester.pumpWidget(host(ListView(
      children: [
        AttendanceHistorySummary(stats: AttendanceStats.empty),
        AttendanceHistoryFilters(
          query: const AttendanceHistoryQuery(),
          onRange: (_, {start, end}) {},
          onStatus: (_) {},
          onToggleShift: (_) {},
        ),
      ],
    )));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('review-mode card leads with the employee name', (tester) async {
    final r = _rec(
      date: DateTime(2026, 7, 15),
      clockIn: DateTime(2026, 7, 15, 8, 30),
      clockOut: DateTime(2026, 7, 15, 16, 30),
    );
    await tester.pumpWidget(host(ListView(
      children: [AttendanceRecordCard(record: r, showEmployee: true)],
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Alice'), findsOneWidget);
  });
}
