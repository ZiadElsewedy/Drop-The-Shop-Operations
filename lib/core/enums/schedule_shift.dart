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

  /// Human-readable default hours (mirrors the Phase 2 shift times). Display
  /// only — the schedule itself stores who works, not the clock times.
  String get timeRange =>
      this == ScheduleShift.morning ? '08:30 – 16:30' : '16:30 – 23:00';

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
