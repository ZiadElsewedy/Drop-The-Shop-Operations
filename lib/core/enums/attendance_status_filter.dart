/// The status facet a user can filter the **Attendance History** ledger by.
///
/// Deliberately a *superset* of [AttendanceStatus](attendance_status.dart): some
/// of these are lifecycle statuses (`absent`, `leave`) while others are **derived**
/// facts off the record's minute fields (`onTime`, `late`, `earlyLeave`,
/// `overtime`) — the same facts the entity exposes as `isLate` / `hasEarlyLeave` /
/// `hasOvertime`. Keeping the *predicate* out of this enum (it lives in the
/// attendance domain's `attendance_history_query.dart`, which may import the
/// entity) preserves the rule that `core/` never imports a feature.
enum AttendanceStatusFilter {
  all,
  onTime,
  late,
  absent,
  leave,
  earlyLeave,
  overtime;

  /// UI label for the filter chip.
  String get label => switch (this) {
        AttendanceStatusFilter.all => 'All',
        AttendanceStatusFilter.onTime => 'On time',
        AttendanceStatusFilter.late => 'Late',
        AttendanceStatusFilter.absent => 'Absent',
        AttendanceStatusFilter.leave => 'Leave',
        AttendanceStatusFilter.earlyLeave => 'Early leave',
        AttendanceStatusFilter.overtime => 'Overtime',
      };

  bool get isAll => this == AttendanceStatusFilter.all;
}
