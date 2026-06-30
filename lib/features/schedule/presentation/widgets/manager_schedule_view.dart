import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/drop_loading_state.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/broken_assignment_banner.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_grid.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/shift_details_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_alert_card.dart';

/// The operations-control schedule surface (Phase 7 redesign), shared by the
/// manager (own branch) and admin (any branch). A weekly **coverage heatmap**
/// grid replaces the old vertical day cards: an admin sees every shift's
/// staffing health at a glance, taps a cell to assign / remove / resolve, and
/// reviews swap requests from a floating alert — answering "who's understaffed,
/// what's broken, what needs approval" in seconds. Hosted in a Scaffold by the
/// page.
class ManagerScheduleView extends StatefulWidget {
  const ManagerScheduleView({super.key, required this.isAdmin});

  /// Admin = pick any branch (branch selector shown). Manager = own branch fixed.
  final bool isAdmin;

  @override
  State<ManagerScheduleView> createState() => _ManagerScheduleViewState();
}

class _ManagerScheduleViewState extends State<ManagerScheduleView> {
  UserEntity? _user;

  /// Optional shift filter (the header "Shift filter"); null = both shifts.
  ScheduleShift? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    _user = context.currentUser;
    if (widget.isAdmin) {
      context.read<BranchCubit>().load();
      context.read<ScheduleCubit>().load(branchId: '');
    } else {
      // Branch directory for the header logo (§8b) — the manager's own branch.
      context.read<BranchCubit>().loadIfNeeded();
      context.read<ScheduleCubit>().load(branchId: _user?.branchId ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    // An approved swap rewrites the roster — refresh the grid the moment a swap
    // action settles (busy → idle), so coverage updates without a manual pull.
    return BlocListener<ShiftSwapCubit, ShiftSwapState>(
      listenWhen: (prev, curr) =>
          prev.maybeWhen(loaded: (_, busy) => busy, orElse: () => false) &&
          curr.maybeWhen(loaded: (_, busy) => !busy, orElse: () => false),
      listener: (context, _) => context.read<ScheduleCubit>().refresh(),
      child: BlocConsumer<ScheduleCubit, ScheduleState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const DropLoadingState(message: 'Loading schedule…'),
          loaded: (branchId, weekStart, schedule, members, busy) =>
              _body(branchId, weekStart, schedule, members, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _body(
    String branchId,
    DateTime weekStart,
    WeeklyScheduleEntity? schedule,
    List<UserEntity> members,
    bool busy,
  ) {
    final cubit = context.read<ScheduleCubit>();
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        _controls(branchId, weekStart, cubit, members.length),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.refresh(),
            color: AppColors.primary,
            backgroundColor: AppColors.darkSurface,
            child: _content(branchId, schedule, members),
          ),
        ),
        _swapFooter(),
      ],
    );
  }

  // ── Controls ───────────────────────────────────────────────────
  Widget _controls(String branchId, DateTime weekStart, ScheduleCubit cubit,
      int memberCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
          AppSpacing.pagePadding, AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        children: [
          _branchHeader(branchId, memberCount),
          const SizedBox(height: AppSpacing.sm),
          if (widget.isAdmin) ...[
            _branchSelector(branchId),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              _weekStepper(Icons.chevron_left_rounded, cubit.previousWeek,
                  'Previous week'),
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text('Week of',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiary)),
                      Text(ScheduleWeek.rangeLabel(weekStart),
                          style: AppTypography.label),
                    ],
                  ),
                ),
              ),
              _weekStepper(
                  Icons.chevron_right_rounded, cubit.nextWeek, 'Next week'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _shiftFilter(),
        ],
      ),
    );
  }

  Widget _weekStepper(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  /// Branch identity header (§8b/§8c) — logo + name + "Weekly Schedule · N
  /// employees" for the schedule's branch.
  Widget _branchHeader(String branchId, int memberCount) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, _) {
        final branch = context.read<BranchCubit>().branchById(branchId);
        final name = branch?.name ??
            (branchId.isEmpty ? 'No branch selected' : 'Branch');
        // Only show the count once a branch is selected (admin all-branches view
        // has no members until one is picked).
        final subtitle = branchId.isEmpty
            ? 'Weekly schedule'
            : 'Weekly Schedule · $memberCount '
                '${memberCount == 1 ? 'employee' : 'employees'}';
        return Row(
          children: [
            BranchAvatar(
                logoUrl: branch?.logoUrl, name: name, size: 34, radius: 10),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _branchSelector(String branchId) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, state) {
        final branches = state.maybeWhen(
          loaded: (b, _) => b,
          orElse: () => const <BranchEntity>[],
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: branchId.isEmpty ? null : branchId,
              isExpanded: true,
              hint: Row(
                children: [
                  const Icon(Icons.store_mall_directory_outlined,
                      size: 18, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Select a branch', style: AppTypography.body),
                ],
              ),
              dropdownColor: AppColors.darkSurfaceElevated,
              borderRadius: AppRadius.cardAll,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textTertiary),
              style: AppTypography.label.copyWith(color: AppColors.textPrimary),
              items: [
                for (final b in branches)
                  DropdownMenuItem(value: b.id, child: Text(b.name)),
              ],
              onChanged: (v) {
                if (v != null) context.read<ScheduleCubit>().selectBranch(v);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _shiftFilter() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          _filterChip('All', null),
          _filterChip('Morning', ScheduleShift.morning),
          _filterChip('Night', ScheduleShift.night),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ScheduleShift? value) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadius.fullAll,
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────
  Widget _content(
    String branchId,
    WeeklyScheduleEntity? schedule,
    List<UserEntity> members,
  ) {
    if (branchId.isEmpty) {
      return _centeredMessage(Icons.store_mall_directory_outlined,
          'Select a branch to view its schedule.');
    }
    if (schedule == null) return _emptySchedule();

    final orphanCount = brokenSlots(schedule, members).length;
    final grid = ScheduleGrid(
      schedule: schedule,
      members: members,
      filter: _filter,
      onCellTap: (day, shift) => showShiftDetailsSheet(
        context: context,
        day: day,
        shift: shift,
        canEdit: true,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.md, AppSpacing.pagePadding, AppSpacing.xl),
      children: [
        _coverageSummary(schedule, members),
        const SizedBox(height: AppSpacing.md),
        if (orphanCount > 0) ...[
          BrokenAssignmentBanner(
            count: orphanCount,
            onReview: () => showResolveBrokenSheet(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _gridHint(),
        const SizedBox(height: AppSpacing.sm),
        // The grid scrolls horizontally inside its own viewport.
        SizedBox(height: grid.height, child: grid),
      ],
    );
  }

  /// One-line affordance hint — the grid scrolls sideways and each cell is
  /// tappable; say so quietly rather than leaving it to be discovered.
  Widget _gridHint() {
    return Row(
      children: [
        const Icon(Icons.touch_app_outlined,
            size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Tap a shift to assign or manage staff · swipe for more days',
              style: AppTypography.caption, maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// Neutral assignment snapshot — how many shifts have someone and how many are
  /// still empty. No staffing target or quota is implied; an empty shift is a
  /// fact for the admin's judgment, not a flagged fault.
  Widget _coverageSummary(
      WeeklyScheduleEntity schedule, List<UserEntity> members) {
    var total = 0;
    var filled = 0;
    for (final day in ScheduleDay.values) {
      for (final shift in ScheduleShift.values) {
        if (_filter != null && shift != _filter) continue;
        total++;
        final valid =
            validAssignments(schedule.employeesFor(day, shift), members).length;
        if (valid > 0) filled++;
      }
    }
    final empty = total - filled;
    final fraction = total == 0 ? 0.0 : filled / total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradient,
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empty == 0
                          ? 'Every shift is covered'
                          : '$filled of $total shifts covered',
                      style: AppTypography.label,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      empty == 0
                          ? 'Nice — the whole week is staffed'
                          : '$empty ${empty == 1 ? 'shift needs' : 'shifts need'} someone',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              _summaryPill('${(fraction * 100).round()}%'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.fullAll,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.darkBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(text,
          style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
    );
  }

  // ── Swap footer ────────────────────────────────────────────────
  Widget _swapFooter() {
    return BlocBuilder<ShiftSwapCubit, ShiftSwapState>(
      builder: (context, state) {
        final count = state.maybeWhen(
          loaded: (swaps, _) =>
              swaps.where((s) => !s.status.isResolved).length,
          orElse: () => 0,
        );
        return SwapAlertCard(
          count: count,
          onReview: () => showSwapQueueSheet(
            context: context,
            currentUid: _user?.uid ?? '',
            showBranch: widget.isAdmin,
          ),
        );
      },
    );
  }

  // ── Empty / placeholder states ─────────────────────────────────
  Widget _emptySchedule() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        const Icon(Icons.event_note_outlined,
            size: 56, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.lg),
        Text('No schedule for this week yet.',
            textAlign: TextAlign.center, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        Text('Create one to start assigning shifts.',
            textAlign: TextAlign.center, style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: FilledButton.icon(
            onPressed: () => context
                .read<ScheduleCubit>()
                .createSchedule(createdBy: _user?.uid),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Schedule'),
          ),
        ),
      ],
    );
  }

  Widget _centeredMessage(IconData icon, String message) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxxl * 2),
        Icon(icon, size: 56, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(message,
              textAlign: TextAlign.center, style: AppTypography.bodySmall),
        ),
      ],
    );
  }
}
