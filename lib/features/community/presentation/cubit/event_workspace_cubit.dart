import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/event_phase.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';
import 'package:drop/features/community/domain/event_readiness.dart';
import 'package:drop/features/community/domain/repositories/event_repository.dart';
import 'event_workspace_state.dart';

/// Owns one event's workspace: it streams the `events/{id}` document (so the hero
/// and every section update live) and applies every edit through **one write
/// path** — `copyWith` the entity, then `EventRepository.updateEvent`. Because the
/// whole workspace is one embedded doc, a milestone toggle, a new task, a status
/// change and a pinned announcement are all the same atomic operation, and the
/// stream reflects each instantly.
///
/// Built on demand per opened event (via `AppDependencies.createEventWorkspaceCubit`)
/// and disposed by its `BlocProvider`. Editing is gated to admin + manager by the
/// UI (mirroring `firestore.rules`); an employee gets the live, read-only story.
class EventWorkspaceCubit extends Cubit<EventWorkspaceState> {
  final EventRepository _repository;
  final UserEntity? _user;
  final String eventId;

  StreamSubscription<EventEntity?>? _sub;
  bool _writing = false;

  EventWorkspaceCubit({
    required EventRepository repository,
    required UserEntity? user,
    required this.eventId,
  })  : _repository = repository,
        _user = user,
        super(const EventWorkspaceState()) {
    _subscribe();
  }

  EventEntity? get _event => state.event;

  void _subscribe() {
    _sub = _repository.watchEvent(eventId).listen(
      (event) {
        if (isClosed) return;
        if (event == null) {
          emit(state.copyWith(status: WorkspaceStatus.notFound));
          return;
        }
        emit(state.copyWith(
          status: WorkspaceStatus.loaded,
          event: event,
          readiness: EventReadiness.assess(event),
          error: null,
        ));
      },
      onError: (Object e, StackTrace st) {
        if (isClosed) return;
        emit(state.copyWith(
          status: WorkspaceStatus.error,
          error: 'Failed to load this event.',
        ));
      },
    );
  }

  void toggleLiveMode() =>
      emit(state.copyWith(liveMode: !state.liveMode));

  // ─── The single write path ────────────────────────────────────────────
  /// Applies [transform] to the current event and persists it. The stream then
  /// re-emits the saved doc, so the UI reflects the change; on failure the last
  /// good event is kept and the message is surfaced as a snackbar.
  Future<void> _mutate(EventEntity Function(EventEntity) transform) async {
    final current = _event;
    if (current == null || _writing) return;
    _writing = true;
    emit(state.copyWith(busy: true));
    try {
      await _repository.updateEvent(transform(current));
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(error: 'Could not save your change.'));
      }
    } finally {
      _writing = false;
      if (!isClosed) emit(state.copyWith(busy: false, error: null));
    }
  }

  String _id() => _repository.newItemId();

  // ─── Lifecycle ────────────────────────────────────────────────────────
  Future<void> advanceStatus() async {
    final next = _event?.status.advanceTo;
    if (next != null) await setStatus(next);
  }

  Future<void> setStatus(EventStatus status) =>
      _mutate((e) => e.copyWith(status: status));

  Future<void> cancelEvent() =>
      _mutate((e) => e.copyWith(status: EventStatus.cancelled));

  Future<void> deleteEvent() async {
    try {
      await _repository.deleteEvent(eventId);
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    }
  }

  // ─── Timeline (milestones) ────────────────────────────────────────────
  Future<void> addMilestone(String title,
      {EventPhase phase = EventPhase.planning, DateTime? dueAt}) {
    final m = EventMilestone(
        id: _id(), title: title.trim(), phase: phase, dueAt: dueAt);
    return _mutate((e) => e.copyWith(milestones: [...e.milestones, m]));
  }

  Future<void> toggleMilestone(String id) => _mutate((e) => e.copyWith(
        milestones: [
          for (final m in e.milestones)
            if (m.id == id)
              m.copyWith(
                done: !m.done,
                completedAt: m.done ? null : DateTime.now(),
                clearCompletedAt: m.done,
              )
            else
              m,
        ],
      ));

  Future<void> removeMilestone(String id) => _mutate((e) =>
      e.copyWith(milestones: e.milestones.where((m) => m.id != id).toList()));

  // ─── Tasks ────────────────────────────────────────────────────────────
  Future<void> addTask(
    String title, {
    TaskPriority priority = TaskPriority.normal,
    String? ownerId,
    String? ownerName,
    DateTime? dueAt,
  }) {
    final t = EventTask(
      id: _id(),
      title: title.trim(),
      priority: priority,
      ownerId: ownerId,
      ownerName: ownerName,
      dueAt: dueAt,
    );
    return _mutate((e) => e.copyWith(tasks: [...e.tasks, t]));
  }

  Future<void> toggleTask(String id) => _mutate((e) => e.copyWith(
        tasks: [
          for (final t in e.tasks)
            if (t.id == id)
              t.copyWith(
                done: !t.done,
                completedAt: t.done ? null : DateTime.now(),
                clearCompletedAt: t.done,
              )
            else
              t,
        ],
      ));

  Future<void> assignTask(String id, {String? ownerId, String? ownerName}) =>
      _mutate((e) => e.copyWith(
            tasks: [
              for (final t in e.tasks)
                if (t.id == id)
                  t.copyWith(ownerId: ownerId, ownerName: ownerName)
                else
                  t,
            ],
          ));

  Future<void> removeTask(String id) => _mutate(
      (e) => e.copyWith(tasks: e.tasks.where((t) => t.id != id).toList()));

  // ─── Team ─────────────────────────────────────────────────────────────
  Future<void> addTeamMember(String name,
      {String role = '', String? department, String? userId}) {
    final a = EventAssignment(
      id: _id(),
      userId: userId,
      name: name.trim(),
      role: role.trim(),
      department: department,
    );
    return _mutate((e) => e.copyWith(team: [...e.team, a]));
  }

  Future<void> toggleTeamConfirmed(String id) => _mutate((e) => e.copyWith(
        team: [
          for (final a in e.team)
            if (a.id == id) a.copyWith(confirmed: !a.confirmed) else a,
        ],
      ));

  Future<void> removeTeamMember(String id) => _mutate(
      (e) => e.copyWith(team: e.team.where((a) => a.id != id).toList()));

  // ─── Inventory ────────────────────────────────────────────────────────
  Future<void> addInventory(String name,
      {String category = '', int quantity = 1, String? ownerName}) {
    final i = EventInventoryItem(
      id: _id(),
      name: name.trim(),
      category: category.trim(),
      quantity: quantity,
      ownerName: ownerName,
    );
    return _mutate((e) => e.copyWith(inventory: [...e.inventory, i]));
  }

  Future<void> toggleInventoryReady(String id) => _mutate((e) => e.copyWith(
        inventory: [
          for (final i in e.inventory)
            if (i.id == id) i.copyWith(ready: !i.ready) else i,
        ],
      ));

  Future<void> removeInventory(String id) => _mutate((e) => e.copyWith(
      inventory: e.inventory.where((i) => i.id != id).toList()));

  // ─── Logistics ────────────────────────────────────────────────────────
  Future<void> addLogistics(String title, {String? detail, String? vendor}) {
    final l = EventLogisticsItem(
        id: _id(), title: title.trim(), detail: detail, vendor: vendor);
    return _mutate((e) => e.copyWith(logistics: [...e.logistics, l]));
  }

  Future<void> toggleLogistics(String id) => _mutate((e) => e.copyWith(
        logistics: [
          for (final l in e.logistics)
            if (l.id == id) l.copyWith(done: !l.done) else l,
        ],
      ));

  Future<void> removeLogistics(String id) => _mutate((e) => e.copyWith(
      logistics: e.logistics.where((l) => l.id != id).toList()));

  // ─── Budget ───────────────────────────────────────────────────────────
  Future<void> addBudgetLine(String label,
      {double estimated = 0, String? category}) {
    final b = EventBudgetLine(
        id: _id(), label: label.trim(), estimated: estimated, category: category);
    return _mutate((e) => e.copyWith(budget: [...e.budget, b]));
  }

  Future<void> setBudgetActual(String id, double? actual) =>
      _mutate((e) => e.copyWith(
            budget: [
              for (final b in e.budget)
                if (b.id == id)
                  b.copyWith(actual: actual, clearActual: actual == null)
                else
                  b,
            ],
          ));

  Future<void> toggleBudgetApproved(String id) => _mutate((e) => e.copyWith(
        budget: [
          for (final b in e.budget)
            if (b.id == id) b.copyWith(approved: !b.approved) else b,
        ],
      ));

  Future<void> removeBudgetLine(String id) => _mutate(
      (e) => e.copyWith(budget: e.budget.where((b) => b.id != id).toList()));

  // ─── Communication ────────────────────────────────────────────────────
  Future<void> postAnnouncement(String body,
      {bool important = false, bool pinned = false}) {
    final a = EventAnnouncement(
      id: _id(),
      authorId: _user?.uid,
      authorName: _user?.displayName,
      body: body.trim(),
      important: important,
      pinned: pinned,
      createdAt: DateTime.now(),
    );
    return _mutate(
        (e) => e.copyWith(announcements: [...e.announcements, a]));
  }

  Future<void> togglePinned(String id) => _mutate((e) => e.copyWith(
        announcements: [
          for (final a in e.announcements)
            if (a.id == id) a.copyWith(pinned: !a.pinned) else a,
        ],
      ));

  Future<void> removeAnnouncement(String id) => _mutate((e) => e.copyWith(
      announcements: e.announcements.where((a) => a.id != id).toList()));

  // ─── After event ──────────────────────────────────────────────────────
  Future<void> saveOutcome(EventOutcome outcome) =>
      _mutate((e) => e.copyWith(outcome: outcome));

  // ─── Identity edits ───────────────────────────────────────────────────
  Future<void> updateDetails({
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    int? expectedAttendance,
  }) =>
      _mutate((e) => e.copyWith(
            title: title,
            description: description,
            location: location,
            startAt: startAt,
            endAt: endAt,
            expectedAttendance: expectedAttendance,
          ));

  Future<void> setHeroImage(File file) async {
    if (_event == null || _writing) return;
    _writing = true;
    emit(state.copyWith(busy: true));
    try {
      final url = await _repository.uploadHeroImage(
        eventId: eventId,
        file: file,
        type: AttachmentType.image,
      );
      await _repository.updateEvent(_event!.copyWith(heroImageUrl: url));
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(error: 'Could not upload the image.'));
    } finally {
      _writing = false;
      if (!isClosed) emit(state.copyWith(busy: false, error: null));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
