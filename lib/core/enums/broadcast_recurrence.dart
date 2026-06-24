/// How a scheduled broadcast repeats (Communications Center — Phase 2 Commit 4).
///
/// - [oneTime] — fires once at the scheduled instant, then disables itself.
/// - [daily] / [weekly] / [monthly] — repeats on that cadence.
/// - [custom] — repeats every `interval` days (the schedule's `interval` field).
///
/// Stored as a string in `broadcastSchedules/{id}.recurrenceType`. Pure Dart —
/// the next-run computation lives in `domain/recurrence_rule.dart`.
enum BroadcastRecurrence {
  oneTime,
  daily,
  weekly,
  monthly,
  custom;

  String get value => name;

  String get label => switch (this) {
        BroadcastRecurrence.oneTime => 'One-time',
        BroadcastRecurrence.daily => 'Daily',
        BroadcastRecurrence.weekly => 'Weekly',
        BroadcastRecurrence.monthly => 'Monthly',
        BroadcastRecurrence.custom => 'Custom',
      };

  bool get isRecurring => this != BroadcastRecurrence.oneTime;

  /// Parses the stored string; unknown / missing → [oneTime] (the safe default).
  static BroadcastRecurrence fromString(String? raw) => switch (raw) {
        'daily' => BroadcastRecurrence.daily,
        'weekly' => BroadcastRecurrence.weekly,
        'monthly' => BroadcastRecurrence.monthly,
        'custom' => BroadcastRecurrence.custom,
        _ => BroadcastRecurrence.oneTime,
      };
}
