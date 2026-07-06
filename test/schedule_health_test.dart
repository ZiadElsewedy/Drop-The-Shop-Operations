import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_health.dart';

UserEntity _member(String uid, String name) => UserEntity(
    uid: uid,
    email: '$uid@drop.test',
    displayName: name,
    authProvider: 'password');

WeeklyScheduleEntity _schedule(
        Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments) =>
    WeeklyScheduleEntity(
      id: 'b1_2026-06-14',
      branchId: 'b1',
      weekStart: DateTime(2026, 6, 14),
      assignments: assignments,
    );

void main() {
  final ahmed = _member('u1', 'Ahmed Maher');
  final omar = _member('u2', 'Omar Ali');

  group('computeScheduleHealth', () {
    test('grouped runs with a day off between them are the healthy shape', () {
      // M · M · M · off · N · N · N — the canonical good pattern: the
      // morning→night switch happens across a rest day, so no findings.
      final health = computeScheduleHealth(
        _schedule({
          ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.monday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
          // Wednesday off
          ScheduleDay.thursday: {ScheduleShift.night: ['u1']},
          ScheduleDay.friday: {ScheduleShift.night: ['u1']},
          ScheduleDay.saturday: {ScheduleShift.night: ['u1']},
        }),
        [ahmed],
      );

      expect(health.findings, isEmpty);
      expect(health.score, 100);
      expect(health.label, 'Healthy');
      expect(health.isHealthy, isTrue);
    });

    test('morning ↔ night ping-pong is flagged with a grouping suggestion',
        () {
      // M · N · M · N · M — two soft flips + two night→morning turnarounds.
      final health = computeScheduleHealth(
        _schedule({
          ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.monday: {ScheduleShift.night: ['u1']},
          ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.wednesday: {ScheduleShift.night: ['u1']},
          ScheduleDay.thursday: {ScheduleShift.morning: ['u1']},
        }),
        [ahmed],
      );

      final kinds = health.findings.map((f) => f.kind).toSet();
      expect(kinds, contains(HealthFindingKind.shortRest));
      expect(kinds, contains(HealthFindingKind.alternation));

      final alternation = health.findings
          .firstWhere((f) => f.kind == HealthFindingKind.alternation);
      expect(alternation.title, contains('Ahmed'));
      expect(alternation.title, contains('4×'));
      expect(alternation.recommendation.toLowerCase(), contains('group'));

      // 2 short rests (−20) + the alternation pattern (−6) → Fair.
      expect(health.score, 74);
      expect(health.label, 'Fair');
      // Short rest sorts above the alternation finding (most pressing first).
      expect(health.findings.first.kind, HealthFindingKind.shortRest);
    });

    test('a full week with no day off is flagged and reads Fair', () {
      final health = computeScheduleHealth(
        _schedule({
          for (final day in ScheduleDay.values)
            day: {ScheduleShift.morning: ['u1']},
        }),
        [ahmed],
      );

      expect(health.findings, hasLength(1));
      expect(health.findings.single.kind, HealthFindingKind.longStreak);
      expect(health.findings.single.title, contains('7 days in a row'));
      expect(health.label, 'Fair');
    });

    test('a big workload spread surfaces a team-level rebalance suggestion',
        () {
      final health = computeScheduleHealth(
        _schedule({
          // Ahmed works 5 days (with a mid-week break), Omar just 1.
          ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.monday: {ScheduleShift.morning: ['u1', 'u2']},
          ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.thursday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.friday: {ScheduleShift.morning: ['u1']},
        }),
        [ahmed, omar],
      );

      final uneven = health.findings
          .where((f) => f.kind == HealthFindingKind.unevenLoad)
          .toList();
      expect(uneven, hasLength(1));
      expect(uneven.single.uid, isNull); // team-level, not personal
      expect(uneven.single.title, contains('Ahmed'));
      expect(uneven.single.title, contains('Omar'));
    });

    test('last week\'s Saturday night counts toward this week\'s short rests',
        () {
      final health = computeScheduleHealth(
        _schedule({
          ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
        }),
        [ahmed],
        previousSaturdayNight: {'u1'},
      );

      final shortRest = health.findings
          .where((f) => f.kind == HealthFindingKind.shortRest)
          .toList();
      expect(shortRest, hasLength(1));
      expect(health.score, 90);
    });

    test('an empty schedule is quietly healthy — nothing to advise on', () {
      final health = computeScheduleHealth(_schedule(const {}), [ahmed, omar]);
      expect(health.findings, isEmpty);
      expect(health.label, 'Healthy');
    });
  });
}
