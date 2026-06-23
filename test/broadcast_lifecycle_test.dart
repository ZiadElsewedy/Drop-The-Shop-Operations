import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/enums/broadcast_audience.dart';
import 'package:fbro/core/enums/broadcast_channel.dart';
import 'package:fbro/core/enums/broadcast_priority.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/features/communications/data/models/broadcast_model.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';

/// Phase 2 — broadcast lifecycle + delivery fields (priority, channel,
/// archivedAt, deletedAt) round-trip cleanly and the derived getters
/// (isActive/isArchived/isDeleted/failedCount) behave, with safe back-compat
/// defaults for legacy docs.
void main() {
  group('BroadcastPriority / BroadcastChannel enums', () {
    test('priority parse + high-delivery flag', () {
      expect(BroadcastPriority.fromString('emergency'),
          BroadcastPriority.emergency);
      expect(BroadcastPriority.fromString('high'), BroadcastPriority.high);
      expect(BroadcastPriority.fromString('low'), BroadcastPriority.low);
      // unknown/missing → normal
      expect(BroadcastPriority.fromString('???'), BroadcastPriority.normal);
      expect(BroadcastPriority.fromString(null), BroadcastPriority.normal);
      expect(BroadcastPriority.high.isHighDelivery, isTrue);
      expect(BroadcastPriority.emergency.isHighDelivery, isTrue);
      expect(BroadcastPriority.normal.isHighDelivery, isFalse);
      expect(BroadcastPriority.emergency.isEmergency, isTrue);
    });

    test('channel parse + push/inbox gating', () {
      expect(BroadcastChannel.fromString('push'), BroadcastChannel.push);
      expect(BroadcastChannel.fromString('inbox'), BroadcastChannel.inbox);
      // unknown/missing → both (widest)
      expect(BroadcastChannel.fromString('???'), BroadcastChannel.both);
      expect(BroadcastChannel.push.sendsPush, isTrue);
      expect(BroadcastChannel.push.writesInbox, isFalse);
      expect(BroadcastChannel.inbox.sendsPush, isFalse);
      expect(BroadcastChannel.inbox.writesInbox, isTrue);
      expect(BroadcastChannel.both.sendsPush, isTrue);
      expect(BroadcastChannel.both.writesInbox, isTrue);
    });
  });

  group('BroadcastModel — Phase 2 fields', () {
    test('priority + channel round-trip through map + callable payload', () {
      final model = BroadcastModel.fromEntity(const BroadcastEntity(
        id: 'b1',
        title: 'Fire drill',
        message: 'Evacuate at 3pm',
        senderId: 'admin',
        senderName: 'HQ',
        audience: BroadcastAudience.allBranches,
        priority: BroadcastPriority.emergency,
        channel: BroadcastChannel.both,
      ));

      expect(model.toMap()['priority'], 'emergency');
      expect(model.toMap()['channel'], 'both');
      expect(model.toCallablePayload()['priority'], 'emergency');
      expect(model.toCallablePayload()['channel'], 'both');

      final back = model.toEntity();
      expect(back.priority, BroadcastPriority.emergency);
      expect(back.channel, BroadcastChannel.both);
    });

    test('archivedAt / deletedAt parse from a doc', () {
      final entity = BroadcastModel.fromMap({
        'title': 't',
        'message': 'm',
        'senderId': 'u',
        'senderName': 'n',
        'audience': 'branch',
        'branchId': 'b1',
        'priority': 'high',
        'channel': 'inbox',
        'recipientCount': 30,
        'deliveredCount': 27,
        'archivedAt': Timestamp.fromDate(DateTime(2026, 6, 22, 9)),
        'deletedAt': null,
      }).toEntity();

      expect(entity.priority, BroadcastPriority.high);
      expect(entity.channel, BroadcastChannel.inbox);
      expect(entity.isArchived, isTrue);
      expect(entity.isDeleted, isFalse);
      expect(entity.isActive, isFalse); // archived ⇒ not active
    });

    test('legacy doc (no Phase-2 fields) defaults to normal / both / active', () {
      final entity = BroadcastModel.fromMap(const {
        'title': 't',
        'message': 'm',
        'senderId': 'u',
        'senderName': 'n',
      }).toEntity();

      expect(entity.priority, BroadcastPriority.normal);
      expect(entity.channel, BroadcastChannel.both);
      expect(entity.isActive, isTrue);
      expect(entity.isArchived, isFalse);
      expect(entity.isDeleted, isFalse);
    });
  });

  group('BroadcastEntity derived getters', () {
    test('failedCount = recipients − delivered (clamped, null until known)', () {
      const sent = BroadcastEntity(
        id: 'b',
        title: 't',
        message: 'm',
        senderId: 'u',
        senderName: 'n',
        recipientCount: 30,
        deliveredCount: 27,
      );
      expect(sent.failedCount, 3);

      const pending = BroadcastEntity(
        id: 'b',
        title: 't',
        message: 'm',
        senderId: 'u',
        senderName: 'n',
        recipientCount: 30,
      );
      expect(pending.failedCount, isNull);

      // Never negative even if delivered somehow exceeds recipients.
      const odd = BroadcastEntity(
        id: 'b',
        title: 't',
        message: 'm',
        senderId: 'u',
        senderName: 'n',
        recipientCount: 5,
        deliveredCount: 7,
      );
      expect(odd.failedCount, 0);
    });

    test('custom (multi-recipient) audience uses its own branch marker', () {
      expect(BroadcastAudience.fromString('custom'), BroadcastAudience.custom);
      expect(BroadcastAudience.custom.isCustom, isTrue);

      final model = BroadcastModel.fromEntity(const BroadcastEntity(
        id: 'c1',
        title: 't',
        message: 'm',
        senderId: 'mgr',
        senderName: 'Mgr',
        senderRole: UserRole.manager,
        audience: BroadcastAudience.custom,
      ));
      // Custom keeps the doc out of every branch/all feed (own marker).
      expect(model.branchId, BroadcastModel.customBranchMarker);
      expect(model.branchId, isNot(''));
      expect(model.branchId, isNot(BroadcastModel.directBranchMarker));

      // The marker maps back to a null entity branch on read.
      final back = model.toEntity();
      expect(back.audience, BroadcastAudience.custom);
      expect(back.branchId, isNull);
    });

    test('isActive only when neither archived nor deleted', () {
      final base = DateTime(2026, 6, 22);
      const active = BroadcastEntity(
          id: 'b', title: 't', message: 'm', senderId: 'u', senderName: 'n');
      expect(active.isActive, isTrue);

      final archived = active.copyWith(archivedAt: base);
      expect(archived.isActive, isFalse);
      expect(archived.isArchived, isTrue);

      final deleted = active.copyWith(deletedAt: base);
      expect(deleted.isActive, isFalse);
      expect(deleted.isDeleted, isTrue);
    });
  });
}
