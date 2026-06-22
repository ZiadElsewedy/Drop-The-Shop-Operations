enum RecurrenceFrequency {
  none,
  daily,
  weekly,
  monthly;

  String get value => name;

  static RecurrenceFrequency fromString(String? s) => switch (s) {
        'daily' => daily,
        'weekly' => weekly,
        'monthly' => monthly,
        _ => none,
      };

  String get label => switch (this) {
        RecurrenceFrequency.none => 'Does not repeat',
        RecurrenceFrequency.daily => 'Daily',
        RecurrenceFrequency.weekly => 'Weekly',
        RecurrenceFrequency.monthly => 'Monthly',
      };
}
