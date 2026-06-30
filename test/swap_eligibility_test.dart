import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/swap_eligibility.dart';

/// Pure-logic verification of the shift-swap "future shifts only" rule (spec §2).
/// No Firebase needed — `now` is injected so the assertions are deterministic.
void main() {
  group('SwapEligibility.slotStart', () {
    test('Sunday morning = week start at 08:30', () {
      final week = DateTime(2026, 6, 21); // a Sunday 00:00
      final slot =
          SwapEligibility.slotStart(week, ScheduleDay.sunday, ScheduleShift.morning);
      expect(slot, DateTime(2026, 6, 21, 8, 30));
    });

    test('Saturday night = week start + 6 days at 16:30', () {
      final week = DateTime(2026, 6, 21);
      final slot =
          SwapEligibility.slotStart(week, ScheduleDay.saturday, ScheduleShift.night);
      expect(slot, DateTime(2026, 6, 27, 16, 30));
    });
  });

  group('SwapEligibility.isRequestable', () {
    // Anchor "now" to a known instant: Wed 24 Jun 2026, 12:00.
    final now = DateTime(2026, 6, 24, 12, 0);
    final week = ScheduleWeek.startOf(now); // Sunday 21 Jun 2026

    test('yesterday shift → invalid', () {
      // Tuesday morning of this week is before `now`.
      expect(
        SwapEligibility.isRequestable(
            week, ScheduleDay.tuesday, ScheduleShift.morning,
            now: now),
        isFalse,
      );
    });

    test("today's already-started shift → invalid", () {
      // Wednesday morning (08:30) has already started by 12:00.
      expect(
        SwapEligibility.isRequestable(
            week, ScheduleDay.wednesday, ScheduleShift.morning,
            now: now),
        isFalse,
      );
    });

    test("today's later shift (not yet started) → valid", () {
      // Wednesday night (16:30) is still ahead at 12:00.
      expect(
        SwapEligibility.isRequestable(
            week, ScheduleDay.wednesday, ScheduleShift.night,
            now: now),
        isTrue,
      );
    });

    test('tomorrow shift → valid', () {
      expect(
        SwapEligibility.isRequestable(
            week, ScheduleDay.thursday, ScheduleShift.morning,
            now: now),
        isTrue,
      );
    });

    test('future week shift → valid', () {
      final nextWeek = week.add(const Duration(days: 7));
      expect(
        SwapEligibility.isRequestable(
            nextWeek, ScheduleDay.monday, ScheduleShift.morning,
            now: now),
        isTrue,
      );
    });

    test('exactly at start time → invalid (must be strictly future)', () {
      // now == Wednesday night start exactly.
      final atStart = DateTime(2026, 6, 24, 16, 30);
      expect(
        SwapEligibility.isRequestable(
            week, ScheduleDay.wednesday, ScheduleShift.night,
            now: atStart),
        isFalse,
      );
    });
  });
}
