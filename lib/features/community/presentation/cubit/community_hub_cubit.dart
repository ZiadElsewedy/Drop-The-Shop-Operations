import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/repositories/event_repository.dart';
import 'community_hub_state.dart';

/// Drives the Community Hub inbox (the event list) for every role, self-scoping:
///   admin              → every event (global visibility);
///   manager / employee → their own branch's events.
///
/// Creating an event lives here (admin + manager only — the UI gates the entry
/// point); a single event's workspace + all section edits live in
/// [EventWorkspaceCubit]. Reuses [BranchRepository] to resolve branch names for
/// the cards, exactly like the Requests / Cases list cubits.
class CommunityHubCubit extends Cubit<CommunityHubState> {
  final EventRepository _repository;
  final BranchRepository _branchRepository;

  UserEntity? _user;
  StreamSubscription<List<EventEntity>>? _sub;
  bool _mutating = false;
  final Map<String, String> _branchNames = {};

  CommunityHubCubit({
    required EventRepository repository,
    required BranchRepository branchRepository,
  })  : _repository = repository,
        _branchRepository = branchRepository,
        super(const CommunityHubState.initial());

  EventRepository get repository => _repository;

  List<EventEntity> get _events => state.events;

  static String _scopeKey(UserEntity u) =>
      '${u.uid}:${u.role.value}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    final sameScope = _user != null && _scopeKey(_user!) == _scopeKey(user);
    if (!forceRefresh && !state.isError && _sub != null && sameScope) return;

    if (!sameScope) _branchNames.clear();
    _user = user;
    _loadBranchNames();

    if (!state.isLoaded) {
      emit(state.copyWith(status: HubStatus.loading));
    }

    await _sub?.cancel();
    _sub = null;

    developer.log(
      '[COMMUNITY] load: role=${user.role.value}, uid=${user.uid}, '
      'branch=${user.branchId ?? '-'}',
      name: 'COMMUNITY',
    );

    final Stream<List<EventEntity>> stream = user.role.isAdmin
        ? _repository.watchAllEvents()
        : _repository.watchBranchEvents(user.branchId ?? '');
    _subscribe(stream);
  }

  void _subscribe(Stream<List<EventEntity>> stream) {
    _sub = stream.listen(
      _emitLoaded,
      onError: (Object error, StackTrace st) {
        developer.log('[COMMUNITY] stream error: $error',
            name: 'COMMUNITY', error: error, stackTrace: st);
        emit(state.copyWith(
          status: HubStatus.error,
          error: 'Failed to load events. Please try again.',
        ));
      },
    );
  }

  void _emitLoaded(List<EventEntity> events) {
    if (isClosed) return;
    emit(state.copyWith(
      status: HubStatus.loaded,
      events: events,
      branchNames: Map.of(_branchNames),
      error: null,
    ));
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user, forceRefresh: true);
  }

  Future<void> _loadBranchNames() async {
    try {
      final list = await _branchRepository.getBranches();
      for (final b in list) {
        _branchNames[b.id] = b.name;
      }
      if (!isClosed && state.isLoaded) {
        emit(state.copyWith(branchNames: Map.of(_branchNames)));
      }
    } catch (_) {}
  }

  /// Creates an event and returns it (with its id) so the caller can open the new
  /// workspace. Admin + manager only (the UI gates the entry point); a manager's
  /// event takes their own branch, an admin passes an explicit [branchId].
  Future<EventEntity?> createEvent({
    required String title,
    required EventType type,
    String? branchId,
    String? location,
    String description = '',
    DateTime? startAt,
    DateTime? endAt,
    int? expectedAttendance,
    String? heroImageUrl,
    bool ownedBySelf = true,
  }) async {
    final user = _user;
    if (user == null || _mutating) return null;
    _mutating = true;
    try {
      final id = _repository.newEventId();
      final event = EventEntity(
        id: id,
        title: title.trim(),
        type: type,
        status: EventStatus.planning,
        heroImageUrl: heroImageUrl,
        description: description.trim(),
        branchId: user.role.isManager ? user.branchId : branchId,
        location: location?.trim(),
        startAt: startAt,
        endAt: endAt,
        ownerId: ownedBySelf ? user.uid : null,
        ownerName: ownedBySelf ? user.displayName : null,
        expectedAttendance: expectedAttendance,
        createdBy: user.uid,
      );
      return await _repository.createEvent(event);
    } on Failure catch (e) {
      emit(state.copyWith(status: HubStatus.error, error: e.message));
      return null;
    } catch (_) {
      emit(state.copyWith(
        status: HubStatus.error,
        error: 'Something went wrong creating the event.',
      ));
      return null;
    } finally {
      _mutating = false;
      // Restore the loaded list (the error emit above is surfaced as a snackbar).
      if (!isClosed && _events.isNotEmpty) {
        emit(state.copyWith(status: HubStatus.loaded, error: null));
      }
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
