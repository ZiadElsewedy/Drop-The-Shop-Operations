import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/drop_logo.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_grid.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

const _exportSize = Size(1600, 900);

/// Opens an opaque route on the root navigator so the final roster is shown
/// above the authenticated desktop shell and sidebar.
Future<void> showScheduleFinalView({
  required BuildContext context,
  required WeeklyScheduleEntity schedule,
  required List<UserEntity> members,
  required BranchEntity? branch,
  ScheduleShift? filter,
  Set<String> previousSaturdayNight = const {},
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: AppColors.darkBg,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: animation,
        child: ScheduleFinalView(
          schedule: schedule,
          members: members,
          branch: branch,
          filter: filter,
          previousSaturdayNight: previousSaturdayNight,
        ),
      ),
    ),
  );
}

/// A real export surface: the toolbar remains visible for navigation while the
/// isolated 1600×900 [RepaintBoundary] is saved as a controls-free PNG.
class ScheduleFinalView extends StatefulWidget {
  const ScheduleFinalView({
    super.key,
    required this.schedule,
    required this.members,
    required this.branch,
    this.filter,
    this.previousSaturdayNight = const {},
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final BranchEntity? branch;
  final ScheduleShift? filter;

  /// Last week's Saturday-night crew — keeps the printed short-rest cues
  /// consistent with the editor grid across the week boundary.
  final Set<String> previousSaturdayNight;

  @override
  State<ScheduleFinalView> createState() => _ScheduleFinalViewState();
}

class _ScheduleFinalViewState extends State<ScheduleFinalView> {
  final _captureKey = GlobalKey();
  bool _saving = false;

  void _openDashboard() {
    final user = context.currentUser;
    if (user == null) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(RouteNames.homeForRole(user.role));
  }

  Future<void> _savePng() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Export canvas is unavailable.');

      // 1600×900 logical canvas → 2400×1350 PNG: crisp on Retina without an
      // unnecessarily huge file or capturing any preview toolbar chrome.
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('PNG encoding failed.');

      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filename = scheduleExportFilename(
        widget.branch?.name ?? 'branch',
        widget.schedule.weekStart,
      );
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (mounted) {
        AppSnackbar.success(context, 'Saved to Downloads · $filename');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not save the schedule PNG.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF080809),
          body: SafeArea(
            child: Column(
              children: [
                _PreviewToolbar(
                  saving: _saving,
                  onBack: () => Navigator.of(context).maybePop(),
                  onDashboard: _openDashboard,
                  onSave: _savePng,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.darkBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withAlpha(150),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: _captureKey,
                            child: SizedBox.fromSize(
                              size: _exportSize,
                              child: _ExportCanvas(widget: widget),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stable, filesystem-safe name for the exported schedule image.
String scheduleExportFilename(String branchName, DateTime weekStart) {
  final safe = branchName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .toLowerCase();
  final y = weekStart.year.toString().padLeft(4, '0');
  final m = weekStart.month.toString().padLeft(2, '0');
  final d = weekStart.day.toString().padLeft(2, '0');
  return '${safe.isEmpty ? 'branch' : safe}_schedule_$y-$m-$d.png';
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.saving,
    required this.onBack,
    required this.onDashboard,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onDashboard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to schedule'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: onDashboard,
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Dashboard'),
              ),
              if (constraints.maxWidth >= 980) ...[
                const SizedBox(width: AppSpacing.md),
                const Text(
                  'Export preview · controls are not included in the PNG',
                  style: AppTypography.caption,
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(saving ? 'Saving…' : 'Save PNG'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportCanvas extends StatelessWidget {
  const _ExportCanvas({required this.widget});

  final ScheduleFinalView widget;

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final members = widget.members;
    final branchName = widget.branch?.name ?? 'Branch';
    final insights = computeScheduleInsights(
      schedule,
      members,
      filter: widget.filter,
      previousSaturdayNight: widget.previousSaturdayNight,
    );
    final assignedUids = <String>{};
    var assignmentCount = 0;
    var staffedSlots = 0;
    final visibleShifts = widget.filter == null ? 2 : 1;
    for (final day in ScheduleDay.values) {
      for (final shift in ScheduleShift.values) {
        if (widget.filter != null && shift != widget.filter) continue;
        final valid = validAssignments(
          schedule.employeesFor(day, shift),
          members,
        );
        assignedUids.addAll(valid);
        assignmentCount += valid.length;
        if (valid.isNotEmpty) staffedSlots++;
      }
    }
    final totalSlots = ScheduleDay.values.length * visibleShifts;

    // Presentation mode (Schedule 5.0): the print-clean roster — no dashed
    // placeholders, hover/drag affordances or empty-state icons; every name
    // shown; leave + day notes included when present.
    final grid = ScheduleGrid(
      schedule: schedule,
      members: members,
      filter: widget.filter,
      insights: insights,
      canEdit: false,
      presentation: true,
      railWidth: 96,
      cellWidth: 180,
      cellHeight: 184,
      headerHeight: 60,
      onCellTap: (_, _) {},
    );

    return ColoredBox(
      color: AppColors.darkBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 42, 52, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FinalHeader(
              branch: widget.branch,
              branchName: branchName,
              weekLabel: ScheduleWeek.rangeLabel(schedule.weekStart),
              shiftLabel: widget.filter?.label,
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.darkBorder),
            const SizedBox(height: 18),
            Row(
              children: [
                _FactPill(
                  icon: Icons.people_outline_rounded,
                  value: '${assignedUids.length}',
                  label: assignedUids.length == 1
                      ? 'team member'
                      : 'team members',
                ),
                const SizedBox(width: AppSpacing.sm),
                _FactPill(
                  icon: Icons.assignment_ind_outlined,
                  value: '$assignmentCount',
                  label: assignmentCount == 1 ? 'assignment' : 'assignments',
                ),
                const SizedBox(width: AppSpacing.sm),
                _FactPill(
                  icon: Icons.event_available_outlined,
                  value: '$staffedSlots',
                  label: staffedSlots == 1 ? 'staffed shift' : 'staffed shifts',
                ),
                const SizedBox(width: AppSpacing.sm),
                _FactPill(
                  icon: Icons.event_busy_outlined,
                  value: '${totalSlots - staffedSlots}',
                  label: totalSlots - staffedSlots == 1
                      ? 'open shift'
                      : 'open shifts',
                ),
                if (insights.leaveEntries > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _FactPill(
                    icon: Icons.beach_access_outlined,
                    value: '${insights.leaveEntries}',
                    label: 'on leave',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0E),
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'WEEKLY ROSTER',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const _LegendDot(
                        color: AppColors.primary,
                        label: 'Today',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: grid.height, child: grid),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const DropLogo(height: 15, color: AppColors.textTertiary),
                const SizedBox(width: 9),
                Text(
                  'OPERATIONS  /  STAFF SCHEDULE',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text('Read-only roster snapshot', style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalHeader extends StatelessWidget {
  const _FinalHeader({
    required this.branch,
    required this.branchName,
    required this.weekLabel,
    required this.shiftLabel,
  });

  final BranchEntity? branch;
  final String branchName;
  final String weekLabel;
  final String? shiftLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BranchAvatar(
          logoUrl: branch?.logoUrl,
          name: branchName,
          size: 52,
          radius: 14,
        ),
        const SizedBox(width: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(branchName, style: AppTypography.h1),
            const SizedBox(height: 3),
            Text(
              shiftLabel == null
                  ? 'Weekly staff schedule'
                  : '$shiftLabel shift schedule',
              style: AppTypography.body,
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'WEEK OF',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(weekLabel, style: AppTypography.h2),
          ],
        ),
      ],
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 7),
          Text(
            '$value ',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
