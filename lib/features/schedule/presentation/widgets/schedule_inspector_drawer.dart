import 'package:flutter/material.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/employee_week_stats.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_health.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_health_card.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The Mac inspector drawer docked beside the schedule grid (Schedule V2).
///
/// Default view: the week overview + Schedule Health + a tappable team roster.
/// Selecting a person swaps in their **week detail** — hours (from the week's
/// resolved shift hours), the morning/night/weekend split, the longest streak,
/// days off and any wellbeing flags. Everything is derived read-only from the
/// loaded roster; the widget owns no state and performs no writes — selection is
/// lifted to the parent via [onSelect], so it drops cleanly into a stateless
/// test.
class ScheduleInspectorDrawer extends StatelessWidget {
  const ScheduleInspectorDrawer({
    super.key,
    required this.schedule,
    required this.members,
    required this.health,
    required this.insights,
    required this.selectedUid,
    required this.onSelect,
    this.width = 340,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final ScheduleHealth health;
  final ScheduleInsights insights;

  /// The employee whose detail is shown; null = the overview. Ignored if the
  /// roster no longer contains them (the drawer falls back to the overview).
  final String? selectedUid;
  final ValueChanged<String?> onSelect;
  final double width;

  UserEntity? get _selected {
    if (selectedUid == null) return null;
    for (final m in members) {
      if (m.uid == selectedUid) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.darkBorder)),
      ),
      child: selected == null ? _overview() : _employee(selected),
    );
  }

  // ── Overview: week totals + health + team roster ───────────────
  Widget _overview() {
    final roster = [...members]
      ..sort((a, b) => userDisplayName(a)
          .toLowerCase()
          .compareTo(userDisplayName(b).toLowerCase()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.xl),
      children: [
        _sectionLabel('This week'),
        const SizedBox(height: AppSpacing.sm),
        _statRow('Morning', '${insights.morningAssignments}'),
        _statRow('Night', '${insights.nightAssignments}'),
        if (insights.leaveEntries > 0)
          _statRow('On leave', '${insights.leaveEntries}'),
        _statRow('Open shifts', '${insights.openCount}'),
        _statRow('People scheduled', '${insights.scheduledPeople}'),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('Schedule health'),
        const SizedBox(height: AppSpacing.sm),
        ScheduleHealthCard(health: health),
        if (roster.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _sectionLabel('Team · tap for detail'),
          const SizedBox(height: AppSpacing.sm),
          for (final m in roster) _teamRow(m),
        ],
      ],
    );
  }

  Widget _teamRow(UserEntity member) {
    final stats = computeEmployeeWeekStats(schedule, member.uid);
    final position = member.position?.trim();
    return InkWell(
      onTap: () => onSelect(member.uid),
      borderRadius: AppRadius.lgAll,
      hoverColor: const Color(0x12FFFFFF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            UserAvatar.fromUser(member, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortName(member),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                  if (position != null && position.isNotEmpty)
                    Text(
                      position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stats.isEmpty
                  ? 'Off'
                  : '${stats.workedDays}d · ${stats.hoursLabel}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ── Employee detail ────────────────────────────────────────────
  Widget _employee(UserEntity member) {
    final stats = computeEmployeeWeekStats(schedule, member.uid);
    final warnings =
        health.findings.where((f) => f.uid == member.uid).toList();
    final position = member.position?.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.xl),
      children: [
        InkWell(
          onTap: () => onSelect(null),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Team',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            UserAvatar.fromUser(member, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userDisplayName(member),
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (position != null && position.isNotEmpty)
                    Text(position,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('This week'),
        const SizedBox(height: AppSpacing.sm),
        _statRow('Weekly hours', stats.hoursLabel),
        _statRow('Morning', '${stats.morningCount}'),
        _statRow('Night', '${stats.nightCount}'),
        _statRow('Weekend days', '${stats.weekendCount}'),
        _statRow('Days worked', '${stats.workedDays}'),
        _statRow('Consecutive days', '${stats.longestRun}'),
        _statRow(
          'Days off',
          stats.offDays.isEmpty
              ? 'None'
              : '${stats.offDays.length} · '
                  '${stats.offDays.map((d) => d.shortLabel).join(', ')}',
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('Week at a glance'),
        const SizedBox(height: AppSpacing.sm),
        _weekGlance(stats),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _sectionLabel('Wellbeing'),
          const SizedBox(height: AppSpacing.sm),
          for (final w in warnings) _warning(w),
        ],
      ],
    );
  }

  Widget _weekGlance(EmployeeWeekStats stats) {
    return Row(
      children: [
        for (final day in ScheduleDay.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Text(
                    day.shortLabel,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary, fontSize: 9),
                  ),
                  const SizedBox(height: 4),
                  _glanceMark(stats.byDay[day] ?? const []),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _glanceMark(List<ScheduleShift> shifts) {
    final off = shifts.isEmpty;
    final label = off
        ? '·'
        : shifts.map((s) => s == ScheduleShift.morning ? 'M' : 'N').join('/');
    return Container(
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: off ? Colors.transparent : AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: off ? AppColors.textTertiary : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1,
        ),
      ),
    );
  }

  Widget _warning(HealthFinding finding) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finding.title,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 1),
                Text(finding.recommendation, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          // The value can be long (e.g. a list of days off) — let it wrap and
          // stay right-aligned rather than overflow the fixed-width drawer.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
