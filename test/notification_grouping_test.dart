import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/enums/notification_type.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';
import 'package:fbro/features/notifications/presentation/notification_format.dart';

/// Notification Center pure helpers (2026-06-23 lean inbox): the All/Unread
/// filter, the action-needed classifier, and the Needs-action/Earlier grouping.
NotificationEntity _n(
  String id, {
  required DateTime at,
  NotificationType type = NotificationType.taskApproved,
  bool read = false,
}) =>
    NotificationEntity(
      id: id,
      recipientUid: 'u1',
      type: type,
      title: 'Title',
      body: 'Body',
      createdAt: at,
      readAt: read ? at : null,
    );

void main() {
  final now = DateTime(2026, 6, 22, 12);

  group('NotificationFilter', () {
    test('all matches everything; unread matches only unread', () {
      final unread = _n('u', at: now, read: false);
      final read = _n('r', at: now, read: true);
      expect(NotificationFilter.all.matches(unread), isTrue);
      expect(NotificationFilter.all.matches(read), isTrue);
      expect(NotificationFilter.unread.matches(unread), isTrue);
      expect(NotificationFilter.unread.matches(read), isFalse);
    });

    test('only All and Unread exist', () {
      expect(NotificationFilter.values.map((f) => f.label).toList(),
          ['All', 'Unread']);
    });
  });

  group('isActionNeeded', () {
    test('assigned / rework / reminder / overdue need action', () {
      expect(isActionNeeded(NotificationType.taskAssigned), isTrue);
      expect(isActionNeeded(NotificationType.taskRework), isTrue);
      expect(isActionNeeded(NotificationType.taskReminder), isTrue);
      expect(isActionNeeded(NotificationType.taskOverdue), isTrue);
    });

    test('approvals / submissions / broadcasts are informational', () {
      expect(isActionNeeded(NotificationType.taskApproved), isFalse);
      expect(isActionNeeded(NotificationType.taskSubmitted), isFalse);
      expect(isActionNeeded(NotificationType.taskRejected), isFalse);
      expect(isActionNeeded(NotificationType.broadcastAnnouncement), isFalse);
    });
  });

  group('groupByPriority', () {
    test('Needs action above Earlier, each newest-first', () {
      final items = [
        _n('approvedOld',
            at: DateTime(2026, 6, 20, 9), type: NotificationType.taskApproved),
        _n('assignedNew',
            at: DateTime(2026, 6, 22, 9), type: NotificationType.taskAssigned),
        _n('reworkOld',
            at: DateTime(2026, 6, 19, 9), type: NotificationType.taskRework),
        _n('broadcastNew',
            at: DateTime(2026, 6, 22, 11),
            type: NotificationType.broadcastAnnouncement),
      ];

      final sections = groupByPriority(items);
      expect(sections.map((s) => s.title).toList(),
          ['Needs action', 'Earlier']);
      // Needs action: assignedNew (newer) before reworkOld.
      expect(sections.first.items.map((n) => n.id).toList(),
          ['assignedNew', 'reworkOld']);
      // Earlier: broadcastNew (newer) before approvedOld.
      expect(sections.last.items.map((n) => n.id).toList(),
          ['broadcastNew', 'approvedOld']);
    });

    test('empty sections are omitted', () {
      final items = [
        _n('a', at: now, type: NotificationType.taskApproved),
        _n('b', at: now, type: NotificationType.broadcastAnnouncement),
      ];
      final sections = groupByPriority(items);
      expect(sections.length, 1);
      expect(sections.single.title, 'Earlier');
    });
  });
}
