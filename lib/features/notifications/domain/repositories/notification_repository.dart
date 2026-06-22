import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';

/// Contract for the in-app notification inbox (Notification System Phase 1).
/// Access is enforced server-side by `firestore.rules` (`notifications/{id}`):
/// a recipient reads/updates their own notifications; the creator stamps
/// themselves as `senderUid` on create.
abstract class NotificationRepository {
  /// Persists one notification document.
  Future<void> create(NotificationEntity notification);

  /// Persists many notifications in a single batched write (multi-recipient
  /// task events — one doc per assignee).
  Future<void> createMany(List<NotificationEntity> notifications);

  /// Realtime feed of [uid]'s notifications, newest first (client-sorted — no
  /// composite index, matching the project's task-query approach).
  Stream<List<NotificationEntity>> watch(String uid);

  /// Marks one notification read (sets `readAt`).
  Future<void> markRead(String id);

  /// Marks every unread notification for [uid] read.
  Future<void> markAllRead(String uid);
}
