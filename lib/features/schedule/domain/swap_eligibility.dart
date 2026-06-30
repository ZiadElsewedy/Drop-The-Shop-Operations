import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';

/// Pure, framework-free validation for **shift-swap requests** (spec §2).
///
/// A swap may only be requested for an **upcoming** shift — a past or already
/// in-progress shift can't be swapped. This is the single source of truth for
/// that rule, enforced in three layers: the request bottom sheet (immediate
/// feedback), [ShiftSwapCubit.requestSwap] (the authoritative client gate), and
/// `firestore.rules` (server backstop — see `swapSlotInFuture`).
///
/// A slot is addressed by (week, [ScheduleDay], [ScheduleShift]); its concrete
/// start instant is derived from the week's Sunday plus the day offset and the
/// shift's start time (mirrors [ScheduleShift.timeRange]).
class SwapEligibility {
  SwapEligibility._();

  /// Morning shifts start 08:30, night shifts 16:30 (mirrors the displayed
  /// [ScheduleShift.timeRange]). Kept here so the requestable check, the entity
  /// getter, and the tests all agree on one definition.
  static (int hour, int minute) _startTime(ScheduleShift shift) =>
      shift == ScheduleShift.morning ? (8, 30) : (16, 30);

  /// The concrete start instant of the (week, [day], [shift]) slot. [weekStart]
  /// is the week's Sunday; [ScheduleDay] is ordered Sunday→Saturday, so its
  /// index is the day offset.
  static DateTime slotStart(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
  ) {
    final (h, m) = _startTime(shift);
    final base = DateTime(weekStart.year, weekStart.month, weekStart.day)
        .add(Duration(days: day.index));
    return DateTime(base.year, base.month, base.day, h, m);
  }

  /// Whether a swap may be requested for this slot — true only when the shift's
  /// start is strictly in the future. Past shifts and a shift that has already
  /// started (or is exactly now) are rejected. [now] is injectable for tests.
  static bool isRequestable(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift, {
    DateTime? now,
  }) =>
      slotStart(weekStart, day, shift).isAfter(now ?? DateTime.now());

  /// User-facing reason shown when [isRequestable] is false.
  static const String pastShiftMessage =
      'You can only request a swap for an upcoming shift — '
      'a past or in-progress shift can’t be swapped.';
}
