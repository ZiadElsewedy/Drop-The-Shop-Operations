import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/attendance/domain/attendance_analytics.dart';

/// The Attendance History **summary strip** — the glanceable "here's the period"
/// facts (present / late / absent / rate / average arrival / worked), computed by
/// the pure [AttendanceStats] over the selected date window. Composes the shared
/// [StatStrip] so it reads the same as every other DROP fact row; late/absent
/// carry a semantic tint **only when non-zero** (calm at zero, like AttentionTile).
class AttendanceHistorySummary extends StatelessWidget {
  const AttendanceHistorySummary({super.key, required this.stats});

  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final expected = stats.presentCount + stats.absentCount;
    return StatStrip(
      stats: [
        Stat(label: 'Present', count: stats.presentCount),
        Stat(
          label: 'Late',
          count: stats.lateCount,
          tone: stats.lateCount > 0 ? AppColors.warning : null,
        ),
        Stat(
          label: 'Absent',
          count: stats.absentCount,
          tone: stats.absentCount > 0 ? AppColors.error : null,
        ),
        // Only shown once there's something to report — a forgiven absence is
        // benign, so it stays out of the strip on a clean period.
        if (stats.excusedCount > 0)
          Stat(label: 'Excused', count: stats.excusedCount),
        Stat(
          label: 'Rate',
          value: expected == 0 ? '—' : '${stats.attendancePercent.round()}%',
        ),
        Stat(label: 'Avg arrival', value: _arrival(stats.avgArrivalMinuteOfDay)),
        Stat(label: 'Worked', value: _worked(stats.workedMinutes)),
      ],
    );
  }

  /// Minutes-past-midnight → a 12-hour wall-clock string (e.g. `9:04 AM`), via
  /// the single date formatter. `—` when nobody clocked in.
  static String _arrival(double? minuteOfDay) {
    if (minuteOfDay == null) return '—';
    final m = minuteOfDay.round();
    return AppDateFormatter.time(DateTime(2000, 1, 1, m ~/ 60, m % 60));
  }

  /// Total worked minutes as `Hh Mm` (e.g. `148h 30m`), or `0h` when none.
  static String _worked(int minutes) {
    if (minutes <= 0) return '0h';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
