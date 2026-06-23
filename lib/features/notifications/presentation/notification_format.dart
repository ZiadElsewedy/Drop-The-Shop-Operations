import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';

/// Shared, **pure** presentation helpers for the Notification Center. Kept out of
/// the widget tree so they can be unit tested (the project's convention for
/// derive logic, like `activity_format` and `branch_workload`).
///
/// The inbox is deliberately lean (2026-06-23 simplification): the only filter is
/// **All / Unread**, and notifications are grouped into **Needs action** (things
/// the user must act on) above **Earlier** (informational) — no search, no type
/// filters, no pin, no date buckets.

/// The inbox toolbar filter — All or Unread only.
enum NotificationFilter {
  all,
  unread;

  String get label => switch (this) {
        NotificationFilter.all => 'All',
        NotificationFilter.unread => 'Unread',
      };

  /// Whether [n] passes this filter.
  bool matches(NotificationEntity n) => switch (this) {
        NotificationFilter.all => true,
        NotificationFilter.unread => n.isUnread,
      };
}

/// Whether a notification requires the recipient to *do* something (vs an
/// informational update). Action-needed events sort to the top of the inbox.
/// Today: a task assigned to you, a rework request, and the two due reminders.
/// Informational: approvals, submissions, and broadcasts.
bool isActionNeeded(NotificationType type) =>
    type == NotificationType.taskAssigned ||
    type == NotificationType.taskRework ||
    type == NotificationType.taskReminder ||
    type == NotificationType.taskOverdue;

/// One titled section in the grouped inbox ("Needs action" / "Earlier").
class NotificationSection {
  final String title;
  final List<NotificationEntity> items;
  const NotificationSection(this.title, this.items);
}

/// Groups [items] into **Needs action** (action-needed types) above **Earlier**
/// (everything else), each newest-first. Empty sections are omitted. Pure /
/// deterministic.
List<NotificationSection> groupByPriority(List<NotificationEntity> items) {
  final needsAction = <NotificationEntity>[];
  final earlier = <NotificationEntity>[];
  for (final n in items) {
    (isActionNeeded(n.type) ? needsAction : earlier).add(n);
  }

  int newestFirst(NotificationEntity a, NotificationEntity b) =>
      b.createdAt.compareTo(a.createdAt);
  needsAction.sort(newestFirst);
  earlier.sort(newestFirst);

  return [
    if (needsAction.isNotEmpty)
      NotificationSection('Needs action', needsAction),
    if (earlier.isNotEmpty) NotificationSection('Earlier', earlier),
  ];
}
