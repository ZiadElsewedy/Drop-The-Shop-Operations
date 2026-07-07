import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/schedule/domain/swap_eligibility.dart';

/// Where a shift sits relative to a moment in time.
enum ShiftPhase { upcoming, active, finished }

/// Pure, framework-free time math for a concrete shift slot — the single place
/// that knows a slot's real start/end **instants** (not display strings).
///
/// The tricky case this exists for: weekend nights (Thu/Fri/Sat) end **00:30
/// the next calendar day**. Computing the end naively as `DateTime(y,m,d,0,30)`
/// puts it BEFORE the 16:30 start and every weekend evening reads "finished".
/// [ScheduleShift.endMinutesOn] returns minutes past the slot day's midnight
/// (1470 for weekend nights, i.e. > 24h), so adding it as a [Duration] rolls
/// the end into the next day correctly.
class ShiftWindow {
  ShiftWindow._();

  /// The slot's start instant (delegates to the swap-eligibility source of
  /// truth so the two never disagree).
  static DateTime start(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
  ) =>
      SwapEligibility.slotStart(weekStart, day, shift);

  /// The slot's end instant — past midnight for weekend nights.
  static DateTime end(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
  ) {
    final base = DateTime(weekStart.year, weekStart.month, weekStart.day)
        .add(Duration(days: day.index));
    return base.add(Duration(minutes: shift.endMinutesOn(day)));
  }

  /// The slot's phase at [now] — the interval is `[start, end)`.
  static ShiftPhase phase(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
    DateTime now,
  ) {
    if (now.isBefore(start(weekStart, day, shift))) return ShiftPhase.upcoming;
    if (now.isBefore(end(weekStart, day, shift))) return ShiftPhase.active;
    return ShiftPhase.finished;
  }

  /// The previous calendar day's **night shift still running past midnight**,
  /// or null. Only weekend nights spill (they end 00:30; weekday nights end
  /// 23:00 the same day), so this is non-null exactly when [now] is in
  /// [00:00, 00:30) and yesterday was Thu/Fri/Sat. The caller still has to
  /// check the person was assigned to that night — including the
  /// Saturday-night → Sunday case, where yesterday's slot lives in the
  /// **previous week's** document (`ScheduleCubit.previousSaturdayNight`).
  static ScheduleDay? spillingNightFrom(DateTime now) {
    if (now.hour != 0 || now.minute >= 30) return null;
    final yesterday =
        ScheduleDay.fromDate(now.subtract(const Duration(days: 1)));
    return yesterday.isWeekend ? yesterday : null;
  }
}
