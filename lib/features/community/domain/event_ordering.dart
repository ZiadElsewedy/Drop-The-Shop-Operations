import 'package:drop/features/community/domain/entities/event_entity.dart';

/// Pure ordering for the Community Hub. The hub reads as a story of what's
/// coming and what's passed, so:
///
///   1. **Live** events first (something is happening *right now*).
///   2. then **active/upcoming** events, soonest start first (undated last).
///   3. then the **archive** — terminal events, most recent start first.
///
/// Deterministic + Flutter-free, so it's unit-tested independently and shared by
/// the repository (list streams) and any hub grouping.
List<EventEntity> sortEventsForHub(List<EventEntity> events) {
  final list = [...events];
  list.sort(_compare);
  return list;
}

/// Only the upcoming/active events, in hub order — the top rail of the hub.
List<EventEntity> upcomingEvents(List<EventEntity> events) =>
    sortEventsForHub(events.where((e) => e.status.isActive).toList());

/// Only the terminal events (completed / archived / cancelled), newest first —
/// the hub's archive.
List<EventEntity> pastEvents(List<EventEntity> events) =>
    sortEventsForHub(events.where((e) => e.status.isTerminal).toList());

int _compare(EventEntity a, EventEntity b) {
  // Live rises above everything.
  if (a.isLive != b.isLive) return a.isLive ? -1 : 1;

  final aActive = a.status.isActive;
  final bActive = b.status.isActive;
  if (aActive != bActive) return aActive ? -1 : 1;

  if (aActive) {
    // Active: soonest first, undated sinks to the bottom of the active group.
    return _byStart(a, b, ascending: true);
  }
  // Terminal: most recent first.
  return _byStart(a, b, ascending: false);
}

int _byStart(EventEntity a, EventEntity b, {required bool ascending}) {
  final da = a.startAt;
  final db = b.startAt;
  if (da == null && db == null) {
    return b.createdAtOrEpoch.compareTo(a.createdAtOrEpoch);
  }
  if (da == null) return 1; // undated after dated
  if (db == null) return -1;
  final cmp = da.compareTo(db);
  return ascending ? cmp : -cmp;
}

extension _EventOrderX on EventEntity {
  DateTime get createdAtOrEpoch =>
      createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}
