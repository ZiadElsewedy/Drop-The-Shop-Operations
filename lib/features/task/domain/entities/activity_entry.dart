import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

part 'activity_entry.freezed.dart';

/// One line in a task's activity timeline. Appended on every status change so
/// managers and employees can see who moved the task and when.
///
/// Phase 10: an event can carry **media [attachments]** (images / videos) — e.g.
/// a submission with four photos, a rework with a video. Attachments belong to
/// the event, not the task, so each submission cycle keeps its own evidence.
@freezed
class ActivityEntry with _$ActivityEntry {
  const factory ActivityEntry({
    /// The [TaskStatus.value] string after the transition.
    required String status,
    /// uid of the person who triggered the change.
    required String actorId,
    /// Denormalised display name (best-effort; falls back to uid).
    String? actorName,
    required DateTime at,
    /// Optional note left with the action (review note, completion note, etc.).
    String? note,
    /// Media attached to this event (images / videos).
    @Default(<TaskAttachment>[]) List<TaskAttachment> attachments,
  }) = _ActivityEntry;
}
