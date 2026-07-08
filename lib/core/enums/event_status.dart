/// Lifecycle of a DROP event, stored as a string in `events/{id}.status`:
///
/// `Draft → Planning → Ready → Live → Completed → Archived`
/// with `Cancelled` reachable from any pre-live/live stage.
///
/// The status is what makes an event feel **alive**: as preparations progress
/// the workspace visually evolves, during [live] it becomes an operational
/// command center, and once [completed]/[archived] it settles into an elegant
/// archive. Colours + icons live in the presentation `event_format.dart` so this
/// enum stays Flutter-free and unit-testable.
enum EventStatus {
  draft,
  planning,
  ready,
  live,
  completed,
  archived,
  cancelled;

  String get value => name;

  bool get isDraft => this == EventStatus.draft;
  bool get isPlanning => this == EventStatus.planning;
  bool get isReady => this == EventStatus.ready;
  bool get isLive => this == EventStatus.live;
  bool get isCompleted => this == EventStatus.completed;
  bool get isArchived => this == EventStatus.archived;
  bool get isCancelled => this == EventStatus.cancelled;

  /// Still in the planning/running lifecycle — the workspace is a live operations
  /// surface (drives the hub's "Upcoming" vs "Past" split).
  bool get isActive => switch (this) {
        EventStatus.draft ||
        EventStatus.planning ||
        EventStatus.ready ||
        EventStatus.live =>
          true,
        _ => false,
      };

  /// The event is over (or called off) — a read-mostly archive.
  bool get isTerminal => !isActive;

  /// Preparation still matters (before the doors open) — the readiness engine
  /// only nags for a pre-live event.
  bool get isPreparing => switch (this) {
        EventStatus.draft || EventStatus.planning || EventStatus.ready => true,
        _ => false,
      };

  String get label => switch (this) {
        EventStatus.draft => 'Draft',
        EventStatus.planning => 'Planning',
        EventStatus.ready => 'Ready',
        EventStatus.live => 'Live',
        EventStatus.completed => 'Completed',
        EventStatus.archived => 'Archived',
        EventStatus.cancelled => 'Cancelled',
      };

  /// A short verb describing the moment — shown as the hero eyebrow.
  String get eyebrow => switch (this) {
        EventStatus.draft => 'Draft — shaping the idea',
        EventStatus.planning => 'In planning',
        EventStatus.ready => 'Ready to go',
        EventStatus.live => 'Happening now',
        EventStatus.completed => 'Completed',
        EventStatus.archived => 'Archived',
        EventStatus.cancelled => 'Cancelled',
      };

  /// The status an owner may **advance** this event to next — the single forward
  /// step in the hero's status control (terminal states have none). Cancelling is
  /// offered separately so it never sits inline with the happy path.
  EventStatus? get advanceTo => switch (this) {
        EventStatus.draft => EventStatus.planning,
        EventStatus.planning => EventStatus.ready,
        EventStatus.ready => EventStatus.live,
        EventStatus.live => EventStatus.completed,
        EventStatus.completed => EventStatus.archived,
        _ => null,
      };

  /// The call-to-action label for [advanceTo].
  String? get advanceLabel => switch (this) {
        EventStatus.draft => 'Start planning',
        EventStatus.planning => 'Mark ready',
        EventStatus.ready => 'Go live',
        EventStatus.live => 'Complete event',
        EventStatus.completed => 'Archive',
        _ => null,
      };

  /// May this event still be cancelled? (Any active stage.)
  bool get canCancel => isActive;

  /// Parses the stored string; unknown/missing → [draft].
  static EventStatus fromString(String? raw) {
    for (final s in EventStatus.values) {
      if (s.name == raw) return s;
    }
    return EventStatus.draft;
  }
}
