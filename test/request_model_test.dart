import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/request_approval_policy.dart';
import 'package:drop/core/enums/request_priority.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/enums/request_type.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/requests/data/models/request_model.dart';
import 'package:drop/features/requests/domain/entities/request_entity.dart';
import 'package:drop/features/requests/domain/entities/request_event.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

void main() {
  group('RequestModel serialization', () {
    test('entity → model → map preserves the core fields + enums', () {
      final entity = RequestEntity(
        id: 'r1',
        branchId: 'b1',
        type: RequestType.stockRequest,
        approvalPolicy: RequestApprovalPolicy.managerOrAdmin,
        status: RequestStatus.pending,
        priority: RequestPriority.high,
        requesterId: 'u1',
        requesterName: 'Sara',
        requesterRole: UserRole.employee,
        details: const {'product': 'Air Max', 'quantity': 3},
      );

      final map = RequestModel.fromEntity(entity).toMap();
      expect(map['type'], 'stockRequest');
      expect(map['approvalPolicy'], 'managerOrAdmin');
      expect(map['status'], 'pending');
      expect(map['priority'], 'high');
      expect(map['requesterId'], 'u1');
      expect(map['requesterRole'], 'employee');
      expect((map['details'] as Map)['quantity'], 3);
    });

    test('fromMap restores enums and defaults leniently', () {
      final model = RequestModel.fromMap({
        'type': 'unknownType',
        'status': 'garbage',
        'priority': null,
        'approvalPolicy': 'nope',
        'requesterId': 'u9',
      }, id: 'r2');
      expect(model.type, RequestType.other);
      expect(model.status, RequestStatus.pending);
      expect(model.priority, RequestPriority.normal);
      expect(model.approvalPolicy, RequestApprovalPolicy.managerOrAdmin);
      expect(model.id, 'r2');
    });

    test('details normalize Timestamp → DateTime on read', () {
      final ts = Timestamp.fromDate(DateTime(2026, 7, 7, 16, 30));
      final model = RequestModel.fromMap({
        'type': 'leaveStore',
        'requesterId': 'u1',
        'details': {'reason': 'lunch', 'returnBy': ts},
      }, id: 'r3');
      expect(model.details['returnBy'], isA<DateTime>());
      expect((model.details['returnBy'] as DateTime).hour, 16);
    });

    test('details normalize DateTime → Timestamp on write', () {
      final model = RequestModel(
        id: 'r4',
        type: RequestType.leaveStore,
        requesterId: 'u1',
        details: {'returnBy': DateTime(2026, 7, 7, 16, 30)},
      );
      final map = model.toMap();
      expect((map['details'] as Map)['returnBy'], isA<Timestamp>());
    });

    test('attachments round-trip through the embedded (de)serializer', () {
      final model = RequestModel(
        id: 'r5',
        type: RequestType.maintenance,
        requesterId: 'u1',
        attachments: [
          TaskAttachment(
            id: 'a1',
            url: 'https://x/a.jpg',
            type: AttachmentType.image,
            uploadedAt: DateTime(2026, 7, 7),
            uploadedBy: 'u1',
          ),
        ],
      );
      final restored =
          RequestModel.fromMap(model.toMap(), id: 'r5').attachments.single;
      expect(restored.id, 'a1');
      expect(restored.type, AttachmentType.image);
    });

    test('event round-trips kind + actor', () {
      final event = RequestEvent(
        id: 'e1',
        authorId: 'mgr',
        authorName: 'Boss',
        actor: RequestEventActor.approver,
        kind: RequestEventKind.comment,
        text: 'please return by 4pm',
        createdAt: DateTime(2026, 7, 7),
      );
      final restored =
          RequestModel.eventFromMap(RequestModel.eventToMap(event), id: 'e1');
      expect(restored.kind, RequestEventKind.comment);
      expect(restored.actor, RequestEventActor.approver);
      expect(restored.text, 'please return by 4pm');
    });
  });
}
