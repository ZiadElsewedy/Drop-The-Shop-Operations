import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';
import 'package:fbro/features/notifications/presentation/notification_format.dart';

/// Phase 2 — Notification Center pure helpers: type filter, search, and
/// date grouping (pinned first).
NotificationEntity _n(
  String id, {
  required DateTime at,
  NotificationType type = NotificationType.taskAssigned,
  String title = 'Title',
  String body = 'Body',
  bool pinned = false,
  bool read = false,
}) =>
    NotificationEntity(
      id: id,
      recipientUid: 'u1',
      type: type,
      title: title,
      body: body,
      createdAt: at,
      readAt: read ? at : null,
      pinnedAt: pinned ? at : null,
    );

void main() {
  final now = DateTime(2026, 6, 22, 12);

  group('NotificationFilter', () {
    final task = _n('t', at: now, type: NotificationType.taskApproved);
    final reminder = _n('rm', at: now, type: NotificationType.taskReminder);
    final bc = _n('b', at: now, type: NotificationType.broadcastAlert);
    final unread = _n('u', at: now, read: false);
    final read = _n('r', at: now, read: true);

    test('task / broadcast partitioning', () {
      expect(NotificationFilter.task.matches(task), isTrue);
      // Reminders are task* — they belong to the Tasks group.
      expect(NotificationFilter.task.matches(reminder), isTrue);
      expect(NotificationFilter.task.matches(bc), isFalse);
      expect(NotificationFilter.broadcast.matches(bc), isTrue);
      expect(NotificationFilter.broadcast.matches(task), isFalse);
      expect(NotificationFilter.all.matches(task), isTrue);
    });

    test('unread filter', () {
      expect(NotificationFilter.unread.matches(unread), isTrue);
      expect(NotificationFilter.unread.matches(read), isFalse);
    });
  });

  group('notificationMatchesQuery', () {
    final n = _n('1', at: now, title: 'Stock count tonight', body: 'Back room');
    test('matches title or body, case-insensitive; empty query matches all', () {
      expect(notificationMatchesQuery(n, ''), isTrue);
      expect(notificationMatchesQuery(n, 'STOCK'), isTrue);
      expect(notificationMatchesQuery(n, 'back room'), isTrue);
      expect(notificationMatchesQuery(n, 'invoice'), isFalse);
    });
  });

  group('groupNotifications', () {
    test('pinned first, then Today / Yesterday / This week / Earlier', () {
      final items = [
        _n('today', at: DateTime(2026, 6, 22, 9)),
        _n('yesterday', at: DateTime(2026, 6, 21, 9)),
        _n('thisWeek', at: DateTime(2026, 6, 18, 9)),
        _n('earlier', at: DateTime(2026, 6, 1, 9)),
        _n('pinnedOld', at: DateTime(2026, 5, 1, 9), pinned: true),
      ];

      final sections = groupNotifications(items, now: now);
      expect(sections.map((s) => s.title).toList(),
          ['Pinned', 'Today', 'Yesterday', 'This week', 'Earlier']);
      // The pinned item is in the Pinned section regardless of its age.
      expect(sections.first.items.single.id, 'pinnedOld');
    });

    test('empty sections are omitted; each section is newest-first', () {
      final items = [
        _n('a', at: DateTime(2026, 6, 22, 8)),
        _n('b', at: DateTime(2026, 6, 22, 11)),
      ];
      final sections = groupNotifications(items, now: now);
      expect(sections.length, 1);
      expect(sections.single.title, 'Today');
      expect(sections.single.items.map((n) => n.id).toList(), ['b', 'a']);
    });
  });
}
