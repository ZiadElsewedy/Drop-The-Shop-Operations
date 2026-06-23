import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';

/// Shared, **pure** presentation helpers for the Notification Center — filtering,
/// search, and date grouping. Kept out of the widget tree so they can be unit
/// tested (the project's convention for derive logic, like `activity_format` and
/// `branch_workload`).

/// A type-group filter for the inbox toolbar. There is no "System" group: every
/// live [NotificationType] is `task*` or `broadcast*` (the schedule/swap/admin
/// types were trimmed in the 2026-06-23 stabilization pass). Re-add a group here
/// only when a real producer for a non-task/non-broadcast type ships.
enum NotificationFilter {
  all,
  unread,
  task,
  broadcast;

  String get label => switch (this) {
        NotificationFilter.all => 'All',
        NotificationFilter.unread => 'Unread',
        NotificationFilter.task => 'Tasks',
        NotificationFilter.broadcast => 'Broadcasts',
      };

  /// Whether [n] passes this filter.
  bool matches(NotificationEntity n) {
    switch (this) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.unread:
        return n.isUnread;
      case NotificationFilter.task:
        return _isTask(n.type);
      case NotificationFilter.broadcast:
        return _isBroadcast(n.type);
    }
  }

  static bool _isTask(NotificationType t) => t.name.startsWith('task');
  static bool _isBroadcast(NotificationType t) => t.name.startsWith('broadcast');
}

/// Case-insensitive match of [query] against a notification's title + body.
bool notificationMatchesQuery(NotificationEntity n, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q);
}

/// One titled section in the grouped inbox (e.g. "Pinned", "Today").
class NotificationSection {
  final String title;
  final List<NotificationEntity> items;
  const NotificationSection(this.title, this.items);
}

/// Groups [items] into ordered sections: **Pinned** first (any pinned, newest
/// first), then unpinned bucketed by date — **Today**, **Yesterday**, **This
/// week**, **Earlier** — each newest first. Empty sections are omitted. Pure /
/// deterministic ([now] injectable for tests).
List<NotificationSection> groupNotifications(
  List<NotificationEntity> items, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(const Duration(days: 7));

  final pinned = <NotificationEntity>[];
  final todayList = <NotificationEntity>[];
  final yesterdayList = <NotificationEntity>[];
  final weekList = <NotificationEntity>[];
  final earlier = <NotificationEntity>[];

  for (final n in items) {
    if (n.isPinned) {
      pinned.add(n);
      continue;
    }
    final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
    if (!d.isBefore(today)) {
      todayList.add(n);
    } else if (d == yesterday) {
      yesterdayList.add(n);
    } else if (d.isAfter(weekStart)) {
      weekList.add(n);
    } else {
      earlier.add(n);
    }
  }

  int newestFirst(NotificationEntity a, NotificationEntity b) =>
      b.createdAt.compareTo(a.createdAt);
  for (final l in [pinned, todayList, yesterdayList, weekList, earlier]) {
    l.sort(newestFirst);
  }

  return [
    if (pinned.isNotEmpty) NotificationSection('Pinned', pinned),
    if (todayList.isNotEmpty) NotificationSection('Today', todayList),
    if (yesterdayList.isNotEmpty) NotificationSection('Yesterday', yesterdayList),
    if (weekList.isNotEmpty) NotificationSection('This week', weekList),
    if (earlier.isNotEmpty) NotificationSection('Earlier', earlier),
  ];
}
