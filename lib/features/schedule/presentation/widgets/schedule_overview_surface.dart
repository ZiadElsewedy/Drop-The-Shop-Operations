import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/schedule/domain/health/schedule_health_analyzer.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';

/// The calm **review band** beneath the grid (Schedule V2 UX polish). The grid
/// is the hero; this band gives the space under it a quiet purpose without
/// competing for attention. It replaces the three bordered "cards" with a single
/// borderless, typography-led region separated by hairlines — less visual weight,
/// more whitespace.
///
///  - **Health** (primary) — the 0–100 score, the five-lens breakdown, and the
///    top findings as one-liners (the fix reveals only on tap).
///  - **Insights** (secondary) — the week's attention facts, at most a few lines.
///  - **Legend** (near-invisible) — collapsed to a single quiet line; it exists
///    for learning, so an experienced manager barely notices it.
///
/// Presentation only: it reads the already-computed [ScheduleHealthReport] +
/// [ScheduleInsights] and consumes the frozen analyzer via its report — no
/// business logic, no new derivation.
class ScheduleOverviewSurface extends StatefulWidget {
  const ScheduleOverviewSurface({
    super.key,
    required this.report,
    required this.insights,
  });

  final ScheduleHealthReport report;
  final ScheduleInsights insights;

  @override
  State<ScheduleOverviewSurface> createState() =>
      _ScheduleOverviewSurfaceState();
}

class _ScheduleOverviewSurfaceState extends State<ScheduleOverviewSurface> {
  /// The category the findings list is filtered to (null = the top ones across
  /// every lens).
  ScheduleRuleCategory? _filter;

  /// The finding whose one-line detail is currently revealed (identity by a
  /// category+title key; collapses naturally when the roster is re-analyzed).
  String? _openKey;

  /// The legend is collapsed by default — it exists for learning, so it stays
  /// almost invisible until asked for.
  bool _legendOpen = false;

  /// The single quiet separator used across the band — a hairline, never a
  /// card border, so the surfaces read as typography with whitespace.
  static const Color _hairline = Color(0x14FFFFFF);

  /// Two columns (Health · Insights+Legend) only once there's room for both to
  /// breathe; below this the band relaxes into a single calm column.
  static const double _twoColumn = 760;

  static Color _dotColor(ScheduleHealthSeverity severity) => switch (severity) {
        ScheduleHealthSeverity.none => AppColors.primary,
        ScheduleHealthSeverity.low => AppColors.textTertiary,
        ScheduleHealthSeverity.medium => AppColors.warning,
        ScheduleHealthSeverity.high => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One quiet hairline anchors the band under the grid instead of
        // wrapping each section in its own bordered, competing dark block.
        const Divider(height: 1, thickness: 1, color: _hairline),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _twoColumn) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _health()),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _insights(),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(
                            height: 1, thickness: 1, color: _hairline),
                        const SizedBox(height: AppSpacing.md),
                        _legend(),
                      ],
                    ),
                  ),
                ],
              );
            }
            // Narrow: a single calm column, sections parted by hairlines.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _health(),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, thickness: 1, color: _hairline),
                const SizedBox(height: AppSpacing.lg),
                _insights(),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, thickness: 1, color: _hairline),
                const SizedBox(height: AppSpacing.md),
                _legend(),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Health ─────────────────────────────────────────────────────
  Widget _health() {
    final report = widget.report;
    // At most three one-liners — the band summarises, it doesn't document.
    final visible = (_filter == null
            ? report.findings
            : [for (final f in report.findings) if (f.category == _filter) f])
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow('Schedule health'),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${report.overallScore}',
                  style: AppTypography.displayMedium.copyWith(height: 1),
                ),
                Text(
                  ' /100',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
            const Spacer(),
            _statusBadge(report),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _summary(report),
          style:
              AppTypography.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.md),
        // The five lenses — tap one to focus the findings on it.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final result in report.results) _categoryPill(result)],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (visible.isEmpty)
          _calmLine(_filter == null
              ? 'Nothing to flag — shifts are grouped and rest looks sustainable.'
              : 'Nothing to flag in ${_filter!.label.toLowerCase()}.')
        else ...[
          _eyebrow(_filter == null ? 'Top findings' : _filter!.label),
          for (final finding in visible) _findingRow(finding),
        ],
      ],
    );
  }

  Widget _statusBadge(ScheduleHealthReport report) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dotColor(report.overallSeverity),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            report.label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _summary(ScheduleHealthReport report) {
    if (report.isHealthy) {
      return 'Every lens is clear — the week reads calm.';
    }
    final n = report.findings.length;
    final areas = report.results.where((r) => !r.isHealthy).length;
    return '$n ${n == 1 ? 'thing' : 'things'} to review across '
        '$areas ${areas == 1 ? 'area' : 'areas'}.';
  }

  Widget _categoryPill(ScheduleRuleResult result) {
    final active = result.findings.isNotEmpty;
    final selected = _filter == result.category;
    return InkWell(
      onTap: active
          ? () => setState(() => _filter = selected ? null : result.category)
          : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkSurfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.textTertiary : AppColors.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: active
                    ? _dotColor(result.severity)
                    : const Color(0x40FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              result.category.label,
              style: AppTypography.caption.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textTertiary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${result.score}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _findingRow(RuleFinding finding) {
    final key = '${finding.category.name}:${finding.title}';
    final open = _openKey == key;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _openKey = open ? null : key),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: _dotColor(finding.severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    finding.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (!open)
                  Text('View',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 4, right: 4),
              child: Text(
                finding.suggestion,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  // ── Insights ───────────────────────────────────────────────────
  // The week's attention facts, at most a handful of lines. The interactive
  // highlight chips above the grid own the "click to see where"; this is the
  // quiet readout that stays visible even with the inspector closed.
  Widget _insights() {
    final ins = widget.insights;
    final facts = <(String, int, Color)>[
      if (ins.openCount > 0) ('Open shifts', ins.openCount, AppColors.warning),
      if (ins.onePersonCount > 0)
        ('Single cover', ins.onePersonCount, AppColors.warning),
      if (ins.doubleBookedCount > 0)
        ('Double-booked', ins.doubleBookedCount, AppColors.error),
      if (ins.shortRestCount > 0)
        ('Short rest', ins.shortRestCount, AppColors.warning),
      if (ins.leaveClashCount > 0)
        ('Leave clash', ins.leaveClashCount, AppColors.error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow('Insights'),
        const SizedBox(height: AppSpacing.md),
        if (facts.isEmpty)
          _calmLine('Fully staffed · no conflicts.')
        else
          for (var i = 0; i < facts.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: facts[i].$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      facts[i].$1,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    '${facts[i].$2}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  // ── Legend (near-invisible) ────────────────────────────────────
  Widget _legend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _legendOpen = !_legendOpen),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                _eyebrow('Legend'),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _legendOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.textTertiary),
                ),
                const Spacer(),
                if (!_legendOpen)
                  Text('M · N · leave · drag',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
        ),
        if (_legendOpen) ...[
          const SizedBox(height: AppSpacing.md),
          _legendRow('M', 'Morning', '08:30 – 16:30'),
          const SizedBox(height: 6),
          _legendRow('N', 'Night', '16:30 – 23:00 · 00:30 wknd'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _leavePill('Annual'),
              _leavePill('Sick'),
              _leavePill('Day off'),
              _leavePill('Pending'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Drag a name to move · drop it on another to swap · '
            '←/→ to nudge · tap a cell to edit.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _legendRow(String tag, String label, String hours) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            tag,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            hours,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _leavePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  // ── Shared bits ────────────────────────────────────────────────
  Widget _eyebrow(String text) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  Widget _calmLine(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle_outline_rounded,
                size: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
}
