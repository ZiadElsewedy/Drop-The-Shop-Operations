import 'package:drop/core/enums/schedule_day.dart';

/// The two daily shift slots a weekly schedule fills (Phase 7) — **Morning** and
/// **Night**, reusing the V1 shift names from Phase 2 (`morning` / `night`).
/// Stored lower-case in `weekly_schedules/{id}.assignments.<day>.<shift>`.
enum ScheduleShift {
  morning,
  night;

  /// The string persisted in Firestore (the lower-case name).
  String get value => name;

  /// Capitalized label for the UI (e.g. `Morning`).
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// The other shift — there are only two, so a swap exchanges a slot for its
  /// opposite (morning ⇄ night). Drives the shift-swap exchange.
  ScheduleShift get opposite =>
      this == ScheduleShift.morning ? ScheduleShift.night : ScheduleShift.morning;

  /// Human-readable default hours (mirrors the Phase 2 shift times). Display
  /// only — the schedule itself stores who works, not the clock times.
  String get timeRange =>
      this == ScheduleShift.morning ? '08:30 – 16:30' : '16:30 – 23:00';

  /// Per-day hours: weekend nights (Thu/Fri/Sat — [ScheduleDay.isWeekend]) run
  /// to **00:30**; every other slot keeps [timeRange]. Display only.
  String timeRangeOn(ScheduleDay day) =>
      this == ScheduleShift.night && day.isWeekend
          ? '16:30 – 00:30'
          : timeRange;

  /// Shift start as minutes past midnight (08:30 → 510 · 16:30 → 990) — the
  /// structured counterpart of [timeRange]. Keep in sync with the display
  /// strings above.
  int get startMinutes => this == ScheduleShift.morning ? 510 : 990;

  /// Shift end as minutes past the **slot day's** midnight. Weekend nights end
  /// 00:30 the next calendar day, so their value is past 24h (1470) — callers
  /// adding it as a [Duration] roll into the next day automatically. Keep in
  /// sync with [timeRangeOn].
  int endMinutesOn(ScheduleDay day) => this == ScheduleShift.morning
      ? 990
      : (day.isWeekend ? 1470 : 1380);

  /// Parses the stored string; unknown/missing → [morning].
  static ScheduleShift fromString(String? raw) =>
      raw == 'night' ? ScheduleShift.night : ScheduleShift.morning;

  /// Parses the stored string **preserving absence** — `morning`/`night` map to
  /// the shift, anything else (including null) → null. Used for an *optional*
  /// shift tag (e.g. a task that may not be shift-specific), where the lossy
  /// [fromString] default would wrongly coerce a missing value to morning.
  static ScheduleShift? fromStringOrNull(String? raw) => switch (raw) {
        'morning' => ScheduleShift.morning,
        'night' => ScheduleShift.night,
        _ => null,
      };
}
