/// Lightweight categorization for a manager/admin operational **note** on a task
/// (Home Dashboard redesign). Drives visual hierarchy on the timeline and future
/// filtering. Stored as the note's `ActivityEntry.status` string (no schema
/// change) — `info` keeps the plain `'note'` kind for back-compat with notes
/// written before categories existed.
enum NoteCategory {
  info,
  warning,
  issue;

  /// The `ActivityEntry.status` value a note of this category is stored under.
  String get activityStatus => switch (this) {
        NoteCategory.info => 'note',
        NoteCategory.warning => 'noteWarning',
        NoteCategory.issue => 'noteIssue',
      };

  String get label => switch (this) {
        NoteCategory.info => 'Info',
        NoteCategory.warning => 'Warning',
        NoteCategory.issue => 'Issue',
      };
}
