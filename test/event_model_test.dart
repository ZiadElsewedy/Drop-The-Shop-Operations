import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/event_phase.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/features/community/data/models/event_model.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';

void main() {
  group('EventModel serialization', () {
    final start = DateTime(2026, 8, 1, 19, 0);
    final due = DateTime(2026, 7, 25);

    final event = EventEntity(
      id: 'evt1',
      title: 'Summer Drop',
      type: EventType.collectionLaunch,
      status: EventStatus.planning,
      description: 'The big one',
      branchId: 'branchA',
      location: 'Flagship',
      startAt: start,
      ownerId: 'u1',
      ownerName: 'Ziad',
      expectedAttendance: 200,
      milestones: [
        EventMilestone(
            id: 'm1',
            title: 'Book venue',
            phase: EventPhase.preparation,
            dueAt: due,
            done: true),
      ],
      team: [
        const EventAssignment(
            id: 'a1', name: 'Sara', role: 'Host', confirmed: true),
      ],
      tasks: [
        EventTask(
            id: 't1',
            title: 'Print posters',
            priority: TaskPriority.high,
            ownerName: 'Omar',
            dueAt: due),
      ],
      inventory: [
        const EventInventoryItem(
            id: 'i1', name: 'Rack', category: 'Decor', quantity: 4, ready: true),
      ],
      logistics: [
        const EventLogisticsItem(
            id: 'l1', title: 'Security', vendor: 'ACME', done: false),
      ],
      budget: [
        const EventBudgetLine(
            id: 'b1',
            label: 'Catering',
            estimated: 5000,
            actual: 4200,
            approved: true),
      ],
      announcements: [
        EventAnnouncement(
            id: 'p1',
            body: 'Doors at 7',
            important: true,
            createdAt: DateTime(2026, 7, 20)),
      ],
      outcome: const EventOutcome(
          revenue: 90000, visitors: 320, wins: ['sold out'], lessons: ['start earlier']),
    );

    test('round-trips through the update map', () {
      final map = EventModel.toUpdateMap(event);
      final back = EventModel.fromMap(map, id: 'evt1');

      expect(back.title, 'Summer Drop');
      expect(back.type, EventType.collectionLaunch);
      expect(back.status, EventStatus.planning);
      expect(back.location, 'Flagship');
      expect(back.startAt, start);
      expect(back.expectedAttendance, 200);

      expect(back.milestones.single.title, 'Book venue');
      expect(back.milestones.single.phase, EventPhase.preparation);
      expect(back.milestones.single.done, isTrue);
      expect(back.milestones.single.dueAt, due);

      expect(back.team.single.name, 'Sara');
      expect(back.team.single.confirmed, isTrue);

      expect(back.tasks.single.priority, TaskPriority.high);
      expect(back.tasks.single.ownerName, 'Omar');

      expect(back.inventory.single.quantity, 4);
      expect(back.inventory.single.ready, isTrue);

      expect(back.logistics.single.vendor, 'ACME');

      expect(back.budget.single.actual, 4200);
      expect(back.budget.single.approved, isTrue);

      expect(back.announcements.single.important, isTrue);
      expect(back.announcements.single.body, 'Doors at 7');

      expect(back.outcome!.revenue, 90000);
      expect(back.outcome!.visitors, 320);
      expect(back.outcome!.wins, ['sold out']);
    });

    test('create map omits id-independent server fields but keeps createdBy', () {
      final map = EventModel.toCreateMap(
          event.copyWith(createdBy: 'admin1'));
      expect(map['createdBy'], 'admin1');
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('nested dates are stored as Firestore Timestamps', () {
      final map = EventModel.toUpdateMap(event);
      final milestones = map['milestones'] as List;
      final first = milestones.first as Map<String, dynamic>;
      expect(first['dueAt'], isA<Timestamp>());
    });

    test('a malformed / empty document decodes to safe defaults', () {
      final e = EventModel.fromMap(<String, dynamic>{}, id: 'x');
      expect(e.title, '');
      expect(e.status, EventStatus.draft);
      expect(e.type, EventType.other);
      expect(e.milestones, isEmpty);
      expect(e.outcome, isNull);
      expect(e.preparationProgress, 0);
    });
  });
}
