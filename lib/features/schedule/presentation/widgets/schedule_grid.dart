import 'package:flutter/material.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:fbro/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:fbro/features/schedule/presentation/widgets/shift_cell.dart';

/// The weekly assignment grid (Phase 7 redesign) — replaces the vertical day
/// cards. Days are columns (Sun→Sat), shifts are two rows (Morning / Night).
/// The shift rail and the day headers are **pinned**; the day cells scroll
/// horizontally together so all seven days stay usable and tappable on a phone
/// (per the mobile constraint).
///
/// Each cell shows **how many employees are assigned** — no staffing quota /
/// target is implied. Orphaned (broken) references are excluded from the count
/// and flagged instead, so the number reflects real, current people.
class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.schedule,
    required this.members,
    required this.onCellTap,
    this.filter,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final void Function(ScheduleDay day, ScheduleShift shift) onCellTap;

  /// When set, only this shift's row is shown (the header "Shift filter"); null
  /// shows both Morning and Night.
  final ScheduleShift? filter;

  static const double _railWidth = 78;
  static const double _cellWidth = 128;
  static const double _cellHeight = 122;
  static const double _headerHeight = 50;

  /// Total intrinsic height for [filter] — lets callers embed the grid in a
  /// scroll view without unbounded-height surprises.
  double get height =>
      _headerHeight + (filter == null ? _cellHeight * 2 : _cellHeight);

  @override
  Widget build(BuildContext context) {
    final today = ScheduleDay.today();
    final shifts = filter == null ? ScheduleShift.values : [filter!];
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned left rail: corner spacer + shift labels.
          Column(
            children: [
              const SizedBox(width: _railWidth, height: _headerHeight),
              for (final s in shifts) _rail(s),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    for (final d in ScheduleDay.values)
                      _dayHeader(d, d == today),
                  ]),
                  for (final s in shifts)
                    Row(children: [
                      for (final d in ScheduleDay.values)
                        _cell(d, s, d == today),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rail(ScheduleShift shift) {
    final isMorning = shift == ScheduleShift.morning;
    return SizedBox(
      width: _railWidth,
      height: _cellHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brightness, not colour, distinguishes the shifts (morning brighter)
            // — keeps the rail strictly monochrome.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isMorning
                    ? AppColors.primarySurface
                    : AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Icon(
                isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                size: 17,
                color:
                    isMorning ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 7),
            Text(shift.label,
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(shift.timeRange,
                style: AppTypography.caption.copyWith(height: 1.1)),
          ],
        ),
      ),
    );
  }

  Widget _dayHeader(ScheduleDay day, bool isToday) {
    final date = schedule.weekStart.add(Duration(days: day.index));
    return SizedBox(
      width: _cellWidth,
      height: _headerHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.shortLabel.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: isToday ? AppColors.primary : AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)
                : null,
            child: Text(
              '${date.day}',
              style: AppTypography.labelSmall.copyWith(
                color: isToday ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(ScheduleDay day, ScheduleShift shift, bool isToday) {
    final uids = schedule.employeesFor(day, shift);
    final valid = validAssignments(uids, members);
    final orphans = orphanAssignments(uids, members);
    final users = [for (final uid in valid) userForUid(uid, members)!];
    return ShiftCell(
      users: users,
      isToday: isToday,
      hasOrphan: orphans.isNotEmpty,
      width: _cellWidth,
      height: _cellHeight,
      onTap: () => onCellTap(day, shift),
    );
  }
}
