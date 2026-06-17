import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/extensions/firestore_extensions.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';

/// Firestore (de)serialization for [WeeklyScheduleEntity] — collection
/// `weekly_schedules/{id}`. The `assignments` map is stored as
/// `{ <day>: { <shift>: [uid, …] } }` with lower-case string keys.
class WeeklyScheduleModel {
  final String id;
  final String branchId;
  final DateTime weekStart;
  final Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WeeklyScheduleModel({
    required this.id,
    required this.branchId,
    required this.weekStart,
    this.assignments = const {},
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory WeeklyScheduleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final raw = map['assignments'] as Map<String, dynamic>? ?? const {};
    final assignments = <ScheduleDay, Map<ScheduleShift, List<String>>>{};
    for (final day in ScheduleDay.values) {
      final dayMap = raw[day.value] as Map<String, dynamic>?;
      assignments[day] = {
        for (final shift in ScheduleShift.values)
          shift: (dayMap?[shift.value] as List?)
                  ?.whereType<String>()
                  .toList() ??
              <String>[],
      };
    }
    return WeeklyScheduleModel(
      id: id ?? map['id'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      weekStart:
          map.date('weekStart') ?? DateTime(1970),
      assignments: assignments,
      createdBy: map['createdBy'] as String?,
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  factory WeeklyScheduleModel.fromEntity(WeeklyScheduleEntity e) =>
      WeeklyScheduleModel(
        id: e.id,
        branchId: e.branchId,
        weekStart: e.weekStart,
        assignments: e.assignments,
        createdBy: e.createdBy,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// An empty schedule for [branchId] in the given [weekStart] week, with every
  /// day/shift seeded to an empty list so the roster grid is stable.
  factory WeeklyScheduleModel.empty({
    required String id,
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
  }) =>
      WeeklyScheduleModel(
        id: id,
        branchId: branchId,
        weekStart: weekStart,
        createdBy: createdBy,
        assignments: {
          for (final day in ScheduleDay.values)
            day: {for (final shift in ScheduleShift.values) shift: <String>[]},
        },
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they're intentionally not included here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'branchId': branchId,
        'weekStart': Timestamp.fromDate(weekStart),
        'assignments': {
          for (final entry in assignments.entries)
            entry.key.value: {
              for (final shiftEntry in entry.value.entries)
                shiftEntry.key.value: shiftEntry.value,
            },
        },
        'createdBy': createdBy,
      };

  WeeklyScheduleEntity toEntity() => WeeklyScheduleEntity(
        id: id,
        branchId: branchId,
        weekStart: weekStart,
        assignments: assignments,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
