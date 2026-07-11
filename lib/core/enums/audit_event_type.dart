import 'package:drop/core/enums/audit_entity_type.dart';

/// The canonical taxonomy of **auditable business actions** in DROP — the
/// `eventType` of a record in the immutable `audit_logs` collection. This answers
/// the **"did WHAT"** question of the audit trail.
///
/// ## Design
/// Each value carries a **stable dotted string id** (`task.approved`,
/// `request.created`, …) that is what actually persists — never the Dart enum
/// name — so the wire format is decoupled from the code identifier and stays
/// legible in the Firestore console. A [defaultEntityType] and human [label] ride
/// along so producers stay a one-liner.
///
/// ## Extensibility (the whole point)
/// Adding a new auditable action is **one enum entry** — a value + its dotted id
/// + default entity + label — and then a single `eventTracking.trackEvent(...)`
/// call at the business site. No new collection, model, datasource, repository
/// method, or index. Newer clients may write ids this build doesn't know; those
/// round-trip as [unknown] instead of crashing ([fromString]), so versions
/// coexist.
///
/// ## Producer status (kept honest, like `NotificationType`)
/// The values below are the agreed taxonomy from the Event Tracking spec. Those
/// marked **LIVE** have a wired producer today; the rest are declared canonical
/// ids ready for their producer to be added in a later pass (each is one
/// `trackEvent` call — see `docs/design/AUDIT_LOG.md` §"Add a new event type").
enum AuditEventType {
  // ── Task lifecycle (LIVE — TaskCubit) ──────────────────────────
  taskAssigned('task.assigned', AuditEntityType.task, 'Task assigned'),
  taskStarted('task.started', AuditEntityType.task, 'Task started'),
  taskCompleted('task.completed', AuditEntityType.task, 'Task completed'),
  taskApproved('task.approved', AuditEntityType.task, 'Task approved'),
  taskRejected('task.rejected', AuditEntityType.task, 'Task rejected'),
  taskReworkRequested(
      'task.rework_requested', AuditEntityType.task, 'Rework requested'),
  taskPhotoUploaded(
      'task.photo_uploaded', AuditEntityType.task, 'Photo uploaded'),

  // ── Media upload analytics (LIVE — TaskCubit.completeAndSubmit) ─
  // The upload-operation lifecycle + metrics (durationMs · byte counts · image/
  // video counts · compressionRatio), distinct from the business fact above.
  // Target the task entity (entityId = taskId) so they sit in its audit history.
  mediaUploadStarted(
      'media.upload_started', AuditEntityType.task, 'Upload started'),
  mediaUploadCompleted(
      'media.upload_completed', AuditEntityType.task, 'Upload completed'),
  mediaUploadFailed(
      'media.upload_failed', AuditEntityType.task, 'Upload failed'),
  mediaUploadCancelled(
      'media.upload_cancelled', AuditEntityType.task, 'Upload cancelled'),

  // ── Operations requests (LIVE — Requests cubits) ───────────────
  requestCreated('request.created', AuditEntityType.request, 'Request created'),
  requestApproved(
      'request.approved', AuditEntityType.request, 'Request approved'),
  requestRejected(
      'request.rejected', AuditEntityType.request, 'Request rejected'),

  // ── Shift swaps (declared — producer: ShiftSwapCubit) ──────────
  shiftSwapRequested(
      'shift_swap.requested', AuditEntityType.shiftSwap, 'Swap requested'),
  shiftSwapApproved(
      'shift_swap.approved', AuditEntityType.shiftSwap, 'Swap approved'),
  shiftSwapRejected(
      'shift_swap.rejected', AuditEntityType.shiftSwap, 'Swap rejected'),

  // ── Session (declared — producer: AuthCubit) ───────────────────
  authLogin('auth.login', AuditEntityType.session, 'Signed in'),
  authLogout('auth.logout', AuditEntityType.session, 'Signed out'),

  // ── Profile / comms (declared — producers: ProfileCubit / BroadcastCubit) ──
  profileUpdated('profile.updated', AuditEntityType.profile, 'Profile updated'),
  broadcastSent('broadcast.sent', AuditEntityType.broadcast, 'Broadcast sent'),

  /// Forward-compatible fallback for an id written by a newer client build.
  unknown('unknown', AuditEntityType.other, 'Unknown event');

  const AuditEventType(this.value, this.defaultEntityType, this.label);

  /// The persisted, wire-stable id (e.g. `task.approved`). Never the enum name.
  final String value;

  /// The entity kind this action targets by default — used when a producer does
  /// not pass an explicit `entityType`.
  final AuditEntityType defaultEntityType;

  /// Short human label for an audit feed / console.
  final String label;

  /// The coarse group this event belongs to (the namespace before the dot) —
  /// handy for grouping an audit feed by domain. Pure derivation from [value].
  String get namespace {
    final dot = value.indexOf('.');
    return dot == -1 ? value : value.substring(0, dot);
  }

  /// Parses the stored dotted id; unknown / missing → [unknown] (so a newer
  /// event id never crashes an older client — versions coexist).
  static AuditEventType fromString(String? raw) {
    if (raw == null) return AuditEventType.unknown;
    for (final t in AuditEventType.values) {
      if (t.value == raw) return t;
    }
    return AuditEventType.unknown;
  }
}
