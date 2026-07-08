/// A chapter of an event's **timeline** — every milestone belongs to one phase,
/// so the Timeline section reads as a story (Planning → Preparation → Launch Day
/// → Closing → Post-event review) rather than a flat to-do list. Pure Dart;
/// ordering drives the vertical spine in the workspace.
enum EventPhase {
  planning,
  preparation,
  launchDay,
  closing,
  postEvent;

  String get value => name;

  String get label => switch (this) {
        EventPhase.planning => 'Planning',
        EventPhase.preparation => 'Preparation',
        EventPhase.launchDay => 'Launch Day',
        EventPhase.closing => 'Closing',
        EventPhase.postEvent => 'Post-event Review',
      };

  /// Position in the timeline spine (0-based) — the phases render in this order.
  int get order => index;

  /// Parses the stored string; unknown/missing → [planning].
  static EventPhase fromString(String? raw) {
    for (final p in EventPhase.values) {
      if (p.name == raw) return p;
    }
    return EventPhase.planning;
  }
}
