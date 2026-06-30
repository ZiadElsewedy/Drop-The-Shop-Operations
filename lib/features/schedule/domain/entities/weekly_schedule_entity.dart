import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';

part 'weekly_schedule_entity.freezed.dart';

/// A branch's weekly shift schedule (Phase 7) — the in-app replacement for the
/// Excel / WhatsApp roster. One document per (branch, week): the [weekStart] is
/// the Sunday at 00:00 that begins the week.
///
/// The roster is a nested map — `day → shift → [employee uids]` — so the same
/// employee can appear on any mix of morning / night slots across the week
/// (3 mornings, 3 nights, mixed, …). A manager owns their branch's schedule; an
/// admin can edit any. Access is enforced server-side in `firestore.rules`
/// (`weekly_schedules/{id}`): admin = all branches · manager = own branch ·
/// employee = read-only on their own branch.
@freezed
class WeeklyScheduleEntity with _$WeeklyScheduleEntity {
  const WeeklyScheduleEntity._();

  const factory WeeklyScheduleEntity({
    required String id,
    required String branchId,

    /// The Sunday (00:00) that starts this week.
    required DateTime weekStart,

    /// Roster: `day → shift → list of employee uids`.
    @Default(<ScheduleDay, Map<ScheduleShift, List<String>>>{})
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,

    /// uid of the manager/admin who created the schedule.
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _WeeklyScheduleEntity;

  /// Employee uids assigned to a given [day] + [shift] (never null).
  List<String> employeesFor(ScheduleDay day, ScheduleShift shift) =>
      assignments[day]?[shift] ?? const [];

  /// Whether [uid] is assigned to [day] + [shift].
  bool isAssigned(String uid, ScheduleDay day, ScheduleShift shift) =>
      employeesFor(day, shift).contains(uid);

  /// All shifts [uid] works on [day] (may be empty, one, or both).
  List<ScheduleShift> shiftsFor(String uid, ScheduleDay day) => [
        for (final shift in ScheduleShift.values)
          if (isAssigned(uid, day, shift)) shift,
      ];

  /// Distinct employee uids scheduled anywhere on [day] (both shifts).
  Set<String> employeesOn(ScheduleDay day) => {
        for (final shift in ScheduleShift.values) ...employeesFor(day, shift),
      };
}
