import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/task/data/models/task_model.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// Verifies the new `tasks.shift` field round-trips through serialization and is
/// back-compatible — a missing or unknown value reads as null ("any"), never
/// coerced to morning.
void main() {
  group('TaskModel.shift serialization', () {
    test('writes the lower-case shift name (or null for "any")', () {
      expect(
          const TaskModel(id: '1', title: 't', shift: ScheduleShift.morning)
              .toMap()['shift'],
          'morning');
      expect(
          const TaskModel(id: '1', title: 't', shift: ScheduleShift.night)
              .toMap()['shift'],
          'night');
      expect(const TaskModel(id: '1', title: 't').toMap()['shift'], isNull);
    });

    test('reads morning / night and preserves absence', () {
      expect(TaskModel.fromMap(const {'shift': 'morning'}).shift,
          ScheduleShift.morning);
      expect(TaskModel.fromMap(const {'shift': 'night'}).shift,
          ScheduleShift.night);
      expect(TaskModel.fromMap(const {}).shift, isNull);
    });

    test('an unknown value degrades to null, not morning', () {
      expect(TaskModel.fromMap(const {'shift': 'graveyard'}).shift, isNull);
    });

    test('round-trips through the entity boundary', () {
      const e = TaskEntity(id: '1', title: 't', shift: ScheduleShift.night);
      expect(TaskModel.fromEntity(e).shift, ScheduleShift.night);
      expect(TaskModel.fromEntity(e).toEntity().shift, ScheduleShift.night);
    });
  });
}
