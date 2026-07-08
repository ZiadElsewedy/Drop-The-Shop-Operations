import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/event_status.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/event_ordering.dart';

EventEntity _e(String id, EventStatus status, {DateTime? start, DateTime? created}) =>
    EventEntity(
      id: id,
      title: id,
      status: status,
      startAt: start,
      createdAt: created,
    );

void main() {
  group('sortEventsForHub', () {
    final now = DateTime(2026, 7, 8);

    test('live rises above everything', () {
      final list = sortEventsForHub([
        _e('planning', EventStatus.planning,
            start: now.add(const Duration(days: 1))),
        _e('live', EventStatus.live,
            start: now.add(const Duration(days: 5))),
        _e('done', EventStatus.completed,
            start: now.subtract(const Duration(days: 1))),
      ]);
      expect(list.first.id, 'live');
      expect(list.last.id, 'done');
    });

    test('active events sort soonest-first, undated last', () {
      final list = upcomingEvents([
        _e('later', EventStatus.planning,
            start: now.add(const Duration(days: 10))),
        _e('undated', EventStatus.planning),
        _e('sooner', EventStatus.ready,
            start: now.add(const Duration(days: 2))),
      ]);
      expect(list.map((e) => e.id).toList(), ['sooner', 'later', 'undated']);
    });

    test('past events are the terminal ones, most recent first', () {
      final list = pastEvents([
        _e('old', EventStatus.completed,
            start: now.subtract(const Duration(days: 30))),
        _e('recent', EventStatus.archived,
            start: now.subtract(const Duration(days: 2))),
        _e('active', EventStatus.planning,
            start: now.add(const Duration(days: 2))),
      ]);
      expect(list.map((e) => e.id).toList(), ['recent', 'old']);
    });
  });
}
