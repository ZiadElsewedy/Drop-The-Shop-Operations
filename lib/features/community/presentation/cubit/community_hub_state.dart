import 'package:drop/features/community/domain/entities/event_entity.dart';

enum HubStatus { initial, loading, loaded, error }

/// State for the Community Hub list. A **plain immutable class** (not freezed) —
/// consistent with the feature's no-codegen value objects; consumers switch on
/// [status]. [events] is already hub-ordered + soft-delete-filtered by the
/// repository; [branchNames] resolves branchId → name for the cards (fills async).
class CommunityHubState {
  final HubStatus status;
  final List<EventEntity> events;
  final Map<String, String> branchNames;
  final String? error;

  const CommunityHubState({
    this.status = HubStatus.initial,
    this.events = const [],
    this.branchNames = const {},
    this.error,
  });

  const CommunityHubState.initial() : this();

  bool get isLoading => status == HubStatus.loading;
  bool get isLoaded => status == HubStatus.loaded;
  bool get isError => status == HubStatus.error;

  CommunityHubState copyWith({
    HubStatus? status,
    List<EventEntity>? events,
    Map<String, String>? branchNames,
    String? error,
  }) =>
      CommunityHubState(
        status: status ?? this.status,
        events: events ?? this.events,
        branchNames: branchNames ?? this.branchNames,
        error: error,
      );
}
