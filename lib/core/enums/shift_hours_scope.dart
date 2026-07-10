/// How far a shift-hours edit reaches (Schedule V2 · Pillar 5) — the manager's
/// answer to *"apply changes to…"*. History is safe in every case: past weeks
/// keep their frozen snapshot regardless.
enum ShiftHoursScope {
  /// Only this week's roster — a frozen per-slot override on this week's doc.
  thisWeek,

  /// Update the reusable template. Schedules created afterward pick it up;
  /// existing weeks (including this one) keep their snapshot.
  future,

  /// Update the template **and** re-stamp this week + every future existing
  /// week. Past weeks stay frozen.
  global;

  String get label => switch (this) {
        ShiftHoursScope.thisWeek => 'This week only',
        ShiftHoursScope.future => 'Future schedules',
        ShiftHoursScope.global => 'Update template globally',
      };

  String get detail => switch (this) {
        ShiftHoursScope.thisWeek =>
          'Changes the hours for this week only.',
        ShiftHoursScope.future =>
          'Updates the template — schedules you create from now on use it. '
              'Existing weeks stay unchanged.',
        ShiftHoursScope.global =>
          'Updates the template and re-applies it to this week and every '
              'future week. Past weeks stay frozen.',
      };
}
