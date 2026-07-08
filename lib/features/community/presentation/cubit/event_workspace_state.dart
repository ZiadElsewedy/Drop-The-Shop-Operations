import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/event_readiness.dart';

enum WorkspaceStatus { loading, loaded, notFound, error }

/// State for a single event's workspace. A **plain immutable class** (not
/// freezed) — consistent with the feature. Carries the live [event], a computed
/// [readiness] (recomputed on every doc change), a [busy] flag for in-flight
/// section writes, and [liveMode] (the command-center transform the user can
/// toggle while an event is live).
class EventWorkspaceState {
  final WorkspaceStatus status;
  final EventEntity? event;
  final EventReadiness? readiness;
  final bool busy;
  final bool liveMode;
  final String? error;

  const EventWorkspaceState({
    this.status = WorkspaceStatus.loading,
    this.event,
    this.readiness,
    this.busy = false,
    this.liveMode = false,
    this.error,
  });

  bool get isLoading => status == WorkspaceStatus.loading;
  bool get isLoaded => status == WorkspaceStatus.loaded && event != null;
  bool get isNotFound => status == WorkspaceStatus.notFound;

  EventWorkspaceState copyWith({
    WorkspaceStatus? status,
    EventEntity? event,
    EventReadiness? readiness,
    bool? busy,
    bool? liveMode,
    String? error,
  }) =>
      EventWorkspaceState(
        status: status ?? this.status,
        event: event ?? this.event,
        readiness: readiness ?? this.readiness,
        busy: busy ?? this.busy,
        liveMode: liveMode ?? this.liveMode,
        error: error,
      );
}
