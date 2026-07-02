import 'package:flutter/material.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';
import 'package:drop/features/schedule/presentation/widgets/assignment_chip.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/shift_cell.dart';

/// The weekly assignment grid (Schedule 3.0) — days are columns (Sun→Sat),
/// shifts are two rows (Morning / Night). The shift rail and the day headers
/// are **pinned**; the day cells scroll horizontally together so all seven
/// days stay usable and tappable on a phone (per the mobile constraint).
///
/// Every assigned person renders as an individual chip (drag / right-click /
/// tap target); [insights] drive per-chip conflict cues and, when
/// [activeInsight] is set, dim every slot outside that insight's highlight.
/// No staffing quota / target is implied. Orphaned (broken) references are
/// excluded and flagged instead, so cells reflect real, current people.
class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.schedule,
    required this.members,
    required this.onCellTap,
    this.filter,
    this.insights,
    this.activeInsight,
    this.canEdit = false,
    this.onMoveChip,
    this.onRemoveChip,
    this.onSwapChip,
    this.onChipActions,
    this.onChipSwapWith,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final void Function(ScheduleDay day, ScheduleShift shift) onCellTap;

  /// When set, only this shift's row is shown (the header "Shift filter"); null
  /// shows both Morning and Night.
  final ScheduleShift? filter;

  /// Week facts (open / one-person / double-booked), computed by the view.
  final ScheduleInsights? insights;

  /// The insight the user selected on the strip — its slots stay lit, the
  /// rest of the grid dims.
  final ScheduleInsightKind? activeInsight;

  final bool canEdit;

  /// Desktop drag-to-move: [data]'s person leaves their source slot for the
  /// drop cell's (day, shift).
  final void Function(
          ChipDragData data, ScheduleDay toDay, ScheduleShift toShift)?
      onMoveChip;

  /// Chip context-menu remove.
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)?
      onRemoveChip;

  /// Desktop drag-to-switch: [data]'s person was dropped onto `withUid`, who
  /// holds (toDay, toShift) — the two trade slots.
  final void Function(ChipDragData data, ScheduleDay toDay,
      ScheduleShift toShift, String withUid)? onSwapChip;

  /// Touch long-press on a chip → the move/switch/remove action sheet
  /// (Schedule 4.0 mobile UX).
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)?
      onChipActions;

  /// Desktop chip context-menu "Switch shifts with…" — the guided flow.
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)?
      onChipSwapWith;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop: when the seven days fit, stretch the cells to fill the
          // width so the week reads as one wide, scan-friendly grid (no
          // horizontal scroll). Mobile: keep fixed cells that scroll sideways.
          final avail = constraints.maxWidth;
          final natural = _railWidth + _cellWidth * 7;
          final fits = avail.isFinite && avail >= natural;
          final cellW =
              fits ? ((avail - _railWidth) / 7).floorToDouble() : _cellWidth;

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                for (final d in ScheduleDay.values)
                  _dayHeader(d, d == today, cellW),
              ]),
              for (final s in shifts)
                Row(children: [
                  for (final d in ScheduleDay.values)
                    _cell(d, s, d == today, cellW),
                ]),
            ],
          );

          return Row(
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
                child: fits
                    ? body
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 4),
                        child: body,
                      ),
              ),
            ],
          );
        },
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

  Widget _dayHeader(ScheduleDay day, bool isToday, double cellWidth) {
    final date = schedule.weekStart.add(Duration(days: day.index));
    return SizedBox(
      width: cellWidth,
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

  Widget _cell(
      ScheduleDay day, ScheduleShift shift, bool isToday, double cellWidth) {
    final uids = schedule.employeesFor(day, shift);
    final valid = validAssignments(uids, members);
    final orphans = orphanAssignments(uids, members);
    final users = [for (final uid in valid) userForUid(uid, members)!];
    final dimmed = activeInsight != null &&
        !(insights?.slotsFor(activeInsight!).contains((day, shift)) ?? false);
    final oppositeUids = validAssignments(
            schedule.employeesFor(day, shift.opposite), members)
        .toSet();
    return ShiftCell(
      key: ValueKey('cell-${day.name}-${shift.name}'),
      users: users,
      day: day,
      shift: shift,
      isToday: isToday,
      hasOrphan: orphans.isNotEmpty,
      width: cellWidth,
      height: _cellHeight,
      onTap: () => onCellTap(day, shift),
      canEdit: canEdit,
      dimmed: dimmed,
      conflictedUids: insights?.doubleBookedByDay[day] ?? const {},
      oppositeUids: oppositeUids,
      onDropChip: onMoveChip == null
          ? null
          : (data) => onMoveChip!(data, day, shift),
      onRemoveUid:
          onRemoveChip == null ? null : (uid) => onRemoveChip!(day, shift, uid),
      onMoveUidToOpposite: onMoveChip == null
          ? null
          : (uid) => onMoveChip!(
              ChipDragData(uid: uid, day: day, shift: shift),
              day,
              shift.opposite),
      onSwapChip: onSwapChip == null
          ? null
          : (data, withUid) => onSwapChip!(data, day, shift, withUid),
      onChipActions: onChipActions == null
          ? null
          : (uid) => onChipActions!(day, shift, uid),
      onChipSwapWith: onChipSwapWith == null
          ? null
          : (uid) => onChipSwapWith!(day, shift, uid),
    );
  }
}
