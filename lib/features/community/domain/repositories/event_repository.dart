import 'dart:io';

import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';

/// Contract for Community Hub event data access. The branch/role model is
/// enforced server-side by `firestore.rules` (admin: all branches · manager +
/// employee: own branch). An event is a single `events/{id}` document with every
/// workspace section embedded, so writes are whole-document updates of the
/// mutable fields — simple, atomic, and no composite index needed (ordering is
/// applied client-side over the small event volume).
abstract class EventRepository {
  /// Every event, newest-first — **admin** (rules reject a non-admin collection
  /// read). Soft-deleted events are filtered out.
  Stream<List<EventEntity>> watchAllEvents();

  /// Events in a single branch — a manager or employee sees their branch's
  /// events. Realtime; soft-deleted filtered out.
  Stream<List<EventEntity>> watchBranchEvents(String branchId);

  /// Realtime stream of one event doc — drives the whole workspace (the hero,
  /// every section, live mode). Emits null if missing / soft-deleted.
  Stream<EventEntity?> watchEvent(String eventId);

  /// One-shot fetch for an event doc (command-style callers + tests).
  Future<EventEntity?> getEvent(String eventId);

  /// A fresh, guaranteed-unique event id — generated up front so a hero image can
  /// be uploaded to `events/{id}/hero.jpg` before the doc is written.
  String newEventId();

  /// A fresh, guaranteed-unique id for an embedded section item (a milestone,
  /// task, budget line…). Stable + collision-free without a server round-trip.
  String newItemId();

  /// Creates a new event (single doc write). Returns it with its generated id.
  Future<EventEntity> createEvent(EventEntity event);

  /// Writes the mutable fields of [event] — identity, schedule, ownership and
  /// **all embedded sections** — in one atomic document update. The cubit
  /// mutates the entity (copyWith) then calls this, so there is one write path
  /// for every workspace edit (toggle a task, add a milestone, change status…).
  Future<void> updateEvent(EventEntity event);

  /// SOFT delete (admin-only) — stamps `deletedAt`; the doc stays as a record and
  /// the hub filters it out. Never a hard Firestore delete.
  Future<void> deleteEvent(String eventId);

  /// Uploads the hero image to `events/{eventId}/hero.<ext>` and returns the
  /// resolved download URL.
  Future<String> uploadHeroImage({
    required String eventId,
    required File file,
    AttachmentType type = AttachmentType.image,
    void Function(int transferred, int total)? onProgress,
  });
}
