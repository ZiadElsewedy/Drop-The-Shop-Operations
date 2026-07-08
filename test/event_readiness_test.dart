import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/core/enums/event_type.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/entities/event_sections.dart';
import 'package:drop/features/community/domain/event_readiness.dart';

EventEntity _event({
  EventStatus status = EventStatus.planning,
  EventType type = EventType.collectionLaunch,
  String? ownerName,
  DateTime? startAt,
  String? location,
  List<EventTask> tasks = const [],
  List<EventAssignment> team = const [],
  List<EventInventoryItem> inventory = const [],
  List<EventBudgetLine> budget = const [],
  String? heroImageUrl,
}) =>
    EventEntity(
      id: 'e1',
      title: 'Test event',
      type: type,
      status: status,
      ownerName: ownerName,
      startAt: startAt,
      location: location,
      tasks: tasks,
      team: team,
      inventory: inventory,
      budget: budget,
      heroImageUrl: heroImageUrl,
    );

void main() {
  group('EventReadiness.assess', () {
    test('a bare event surfaces the core blockers', () {
      final r = EventReadiness.assess(_event());
      final titles = r.blockers.map((b) => b.title).toList();
      expect(titles, contains('No event owner'));
      expect(titles, contains('No date set'));
      expect(titles, contains('Nobody assigned'));
      expect(r.hasBlockers, isTrue);
      expect(r.headline, 'Needs attention');
    });

    test('an unowned task is flagged as a blocker', () {
      final r = EventReadiness.assess(_event(
        ownerName: 'Ziad',
        startAt: DateTime.now().add(const Duration(days: 20)),
        team: [const EventAssignment(id: 't', name: 'A', confirmed: true)],
        tasks: [const EventTask(id: '1', title: 'Do a thing')],
      ));
      expect(r.blockers.map((b) => b.title).join(),
          contains('1 task with no owner'));
    });

    test('over-budget is a blocker', () {
      final r = EventReadiness.assess(_event(
        budget: [
          const EventBudgetLine(
              id: 'b', label: 'Catering', estimated: 100, actual: 250),
        ],
      ));
      expect(r.blockers.map((b) => b.title), contains('Over budget'));
    });

    test('a well-prepared event scores high with no blockers', () {
      final done = [
        for (var i = 0; i < 5; i++)
          EventTask(
              id: '$i', title: 'Task $i', ownerName: 'Owner', done: true),
      ];
      final r = EventReadiness.assess(_event(
        ownerName: 'Ziad',
        startAt: DateTime.now().add(const Duration(days: 30)),
        location: 'Flagship',
        heroImageUrl: 'https://x/y.jpg',
        team: [const EventAssignment(id: 't', name: 'A', confirmed: true)],
        tasks: done,
        inventory: [
          const EventInventoryItem(id: 'i', name: 'Rack', ready: true)
        ],
        budget: [
          const EventBudgetLine(
              id: 'b', label: 'Print', estimated: 100, actual: 80, approved: true)
        ],
      ));
      expect(r.hasBlockers, isFalse);
      expect(r.score, greaterThanOrEqualTo(80));
      expect(r.headline, 'On track');
      expect(r.wins, isNotEmpty);
    });

    test('score is bounded 0..100', () {
      final r = EventReadiness.assess(_event());
      expect(r.score, inInclusiveRange(0, 100));
    });

    test('internal events do not demand inventory', () {
      final r = EventReadiness.assess(_event(
        type: EventType.internalTraining,
        ownerName: 'Ziad',
        startAt: DateTime.now().add(const Duration(days: 10)),
        team: [const EventAssignment(id: 't', name: 'A', confirmed: true)],
        tasks: [const EventTask(id: '1', title: 'x', ownerName: 'Y')],
      ));
      expect(r.warnings.map((w) => w.title), isNot(contains('No inventory tracked')));
    });
  });
}
