import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/drop_loading_state.dart';
import 'package:drop/core/widgets/drop_logo.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/move_validation.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/swap_policy.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/schedule_insights.dart';
import 'package:drop/features/schedule/presentation/widgets/assignment_chip.dart'
    show ChipDragData;
import 'package:drop/features/schedule/presentation/widgets/broken_assignment_banner.dart';
import 'package:drop/features/schedule/presentation/widgets/chip_action_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_grid.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/shift_details_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_alert_card.dart'
    show showSwapQueueSheet;

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

  /// The insight chip the user toggled on — its slots stay lit, the rest of
  /// the grid dims. Cleared when the shift filter changes.
  ScheduleInsightKind? _activeInsight;

  /// Drives the undo bar's auto-dismiss explicitly instead of relying on
  /// [SnackBar]'s built-in `duration` — that timer pauses while the bar is
  /// hovered (desktop) and can be left orphaned by a rapid rebuild, which is
  /// why the bar was observed staying on screen well past its 5s window.
  Timer? _undoDismissTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _undoDismissTimer?.cancel();
    super.dispose();
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
      ],
    );
  }

  // ── Controls ───────────────────────────────────────────────────
  Widget _controls(
    String branchId,
    DateTime weekStart,
    ScheduleCubit cubit,
    int memberCount,
  ) {
    if (context.isDesktop) {
      return _desktopControls(branchId, weekStart, cubit, memberCount);
    }
    return _mobileControls(branchId, weekStart, cubit, memberCount);
  }

  /// Desktop: a single dense operations toolbar — branch identity on the left,
  /// branch picker, week navigator and shift filter aligned on the right.
  Widget _desktopControls(
    String branchId,
    DateTime weekStart,
    ScheduleCubit cubit,
    int memberCount,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 16, 40, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          Expanded(child: _branchHeader(branchId, memberCount)),
          if (widget.isAdmin) ...[
            const SizedBox(width: AppSpacing.lg),
            SizedBox(width: 260, child: _branchSelector(branchId)),
          ],
          const SizedBox(width: AppSpacing.lg),
          _weekNavigator(weekStart, cubit),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(width: 280, child: _shiftFilter()),
        ],
      ),
    );
  }

  /// Compact horizontal week navigator (prev · range · next) for the toolbar.
  Widget _weekNavigator(DateTime weekStart, ScheduleCubit cubit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _weekStepper(
          Icons.chevron_left_rounded,
          cubit.previousWeek,
          'Previous week',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Week of',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                ScheduleWeek.rangeLabel(weekStart),
                style: AppTypography.label,
              ),
            ],
          ),
        ),
        _weekStepper(Icons.chevron_right_rounded, cubit.nextWeek, 'Next week'),
      ],
    );
  }

  Widget _mobileControls(
    String branchId,
    DateTime weekStart,
    ScheduleCubit cubit,
    int memberCount,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.md,
      ),
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
              _weekStepper(
                Icons.chevron_left_rounded,
                cubit.previousWeek,
                'Previous week',
              ),
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Week of',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        ScheduleWeek.rangeLabel(weekStart),
                        style: AppTypography.label,
                      ),
                    ],
                  ),
                ),
              ),
              _weekStepper(
                Icons.chevron_right_rounded,
                cubit.nextWeek,
                'Next week',
              ),
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
        final name =
            branch?.name ??
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
              logoUrl: branch?.logoUrl,
              name: name,
              size: 34,
              radius: 10,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Select a branch', style: AppTypography.body),
                ],
              ),
              dropdownColor: AppColors.darkSurfaceElevated,
              borderRadius: AppRadius.cardAll,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textTertiary,
              ),
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
        onTap: () => setState(() {
          _filter = value;
          _activeInsight = null;
        }),
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
      return const DropEmptyState(
        title: 'Pick a branch',
        message: 'Select a branch to view its schedule.',
      );
    }
    if (schedule == null) return _emptySchedule();

    final orphanCount = brokenSlots(schedule, members).length;
    final insights = computeScheduleInsights(
      schedule,
      members,
      filter: _filter,
    );
    // Never leave the grid stuck dim on a stale selection (e.g. the last
    // conflict was just resolved) — an insight with no slots is no filter.
    final activeInsight =
        _activeInsight != null && insights.slotsFor(_activeInsight!).isNotEmpty
        ? _activeInsight
        : null;

    final grid = ScheduleGrid(
      schedule: schedule,
      members: members,
      filter: _filter,
      insights: insights,
      activeInsight: activeInsight,
      canEdit: true,
      onCellTap: (day, shift) => showShiftDetailsSheet(
        context: context,
        day: day,
        shift: shift,
        canEdit: true,
      ),
      // Every edit path funnels through the validated helpers below —
      // blocked edits state their reason, successful ones offer UNDO.
      onMoveChip: (data, toDay, toShift) =>
          _moveChip(schedule, members, data, toDay, toShift),
      onRemoveChip: (day, shift, uid) =>
          _removeChip(schedule, members, day, shift, uid),
      // Drop a person ON another person → the two trade slots.
      onSwapChip: (data, toDay, toShift, withUid) =>
          _exchangeChips(schedule, members, data, toDay, toShift, withUid),
      // Touch long-press → the premium action sheet; desktop context-menu
      // "Switch shifts with…" opens the same flow at its picker step.
      onChipActions: (day, shift, uid) =>
          _openChipActions(schedule, members, day, shift, uid),
      onChipSwapWith: (day, shift, uid) => _openChipActions(
        schedule,
        members,
        day,
        shift,
        uid,
        startAtSwap: true,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        AppSpacing.xl,
      ),
      children: [
        _insightStrip(insights, activeInsight),
        const SizedBox(height: AppSpacing.md),
        if (orphanCount > 0) ...[
          BrokenAssignmentBanner(
            count: orphanCount,
            onReview: () => showResolveBrokenSheet(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // The grid scrolls horizontally inside its own viewport.
        SizedBox(height: grid.height, child: grid),
        const SizedBox(height: AppSpacing.sm),
        _gridHint(),
      ],
    );
  }

  // ── Validated roster edits + undo (Schedule 4.0) ───────────────
  /// The branch's swap policy — the same rule set employee swaps obey, so a
  /// manager's direct switch can never contradict what employees are told.
  SwapPolicy _policy(String branchId) =>
      context.read<BranchCubit>().branchById(branchId)?.effectiveSwapPolicy ??
      SwapPolicy.permissive;

  Future<void> _moveChip(
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    ChipDragData data,
    ScheduleDay toDay,
    ScheduleShift toShift,
  ) async {
    final cubit = context.read<ScheduleCubit>();
    final user = userForUid(data.uid, members);
    final name = user == null ? 'This person' : shortName(user);
    final reason = MoveValidation.checkMove(
      schedule: schedule,
      uid: data.uid,
      name: name,
      fromDay: data.day,
      fromShift: data.shift,
      toDay: toDay,
      toShift: toShift,
    );
    if (reason != null) {
      AppSnackbar.error(context, reason);
      return;
    }
    // Fact, not quota: emptying the source shift is allowed, but never silent.
    if (MoveValidation.wouldEmptySlot(
      schedule: schedule,
      uid: data.uid,
      day: data.day,
      shift: data.shift,
    )) {
      final go = await showConfirmDialog(
        context,
        title: 'Leave shift unstaffed?',
        message:
            'Moving $name leaves ${data.day.label} '
            '${data.shift.label.toLowerCase()} with no one assigned.',
        confirmLabel: 'Move anyway',
      );
      if (!go || !mounted) return;
    }
    final ok = await cubit.move(
      fromDay: data.day,
      fromShift: data.shift,
      toDay: toDay,
      toShift: toShift,
      uid: data.uid,
    );
    if (ok && mounted) {
      _showUndoSnackbar(
        'Moved $name to ${toDay.label} ${toShift.label.toLowerCase()}',
      );
    }
  }

  Future<void> _exchangeChips(
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    ChipDragData data,
    ScheduleDay toDay,
    ScheduleShift toShift,
    String withUid,
  ) async {
    final cubit = context.read<ScheduleCubit>();
    final a = userForUid(data.uid, members);
    final b = userForUid(withUid, members);
    final nameA = a == null ? 'This person' : shortName(a);
    final nameB = b == null ? 'their coworker' : shortName(b);
    final reason = MoveValidation.checkExchange(
      schedule: schedule,
      uidA: data.uid,
      nameA: nameA,
      dayA: data.day,
      shiftA: data.shift,
      uidB: withUid,
      nameB: nameB,
      dayB: toDay,
      shiftB: toShift,
      positionA: a?.position,
      positionB: b?.position,
      policy: _policy(schedule.branchId),
    );
    if (reason != null) {
      AppSnackbar.error(context, reason);
      return;
    }
    final ok = await cubit.exchange(
      dayA: data.day,
      shiftA: data.shift,
      uidA: data.uid,
      dayB: toDay,
      shiftB: toShift,
      uidB: withUid,
    );
    if (ok && mounted) _showUndoSnackbar('Switched $nameA ⇄ $nameB');
  }

  Future<void> _removeChip(
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    ScheduleDay day,
    ScheduleShift shift,
    String uid,
  ) async {
    final cubit = context.read<ScheduleCubit>();
    final user = userForUid(uid, members);
    final name = user == null ? 'This person' : shortName(user);
    if (MoveValidation.wouldEmptySlot(
      schedule: schedule,
      uid: uid,
      day: day,
      shift: shift,
    )) {
      final go = await showConfirmDialog(
        context,
        title: 'Leave shift unstaffed?',
        message:
            'Removing $name leaves ${day.label} '
            '${shift.label.toLowerCase()} with no one assigned.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!go || !mounted) return;
    }
    final ok = await cubit.remove(day, shift, uid);
    if (ok && mounted) {
      _showUndoSnackbar(
        'Removed $name from ${day.label} ${shift.label.toLowerCase()}',
      );
    }
  }

  void _openChipActions(
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    ScheduleDay day,
    ScheduleShift shift,
    String uid, {
    bool startAtSwap = false,
  }) {
    final user = userForUid(uid, members);
    if (user == null) return;
    showChipActionSheet(
      context: context,
      schedule: schedule,
      members: members,
      user: user,
      day: day,
      shift: shift,
      policy: _policy(schedule.branchId),
      startAtSwap: startAtSwap,
      onMove: (toDay, toShift) => _moveChip(
        schedule,
        members,
        ChipDragData(uid: uid, day: day, shift: shift),
        toDay,
        toShift,
      ),
      onExchange: (withUid, withDay, withShift) => _exchangeChips(
        schedule,
        members,
        ChipDragData(uid: uid, day: day, shift: shift),
        withDay,
        withShift,
        withUid,
      ),
      onRemove: () => _removeChip(schedule, members, day, shift, uid),
    );
  }

  /// Premium monochrome undo bar — the safety net for every direct roster
  /// edit, shown for exactly the cubit's undo window.
  void _showUndoSnackbar(String message) {
    final cubit = context.read<ScheduleCubit>();
    final messenger = ScaffoldMessenger.of(context);
    _undoDismissTimer?.cancel();
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.darkSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        // No `duration` reliance here — the explicit timer below owns the
        // dismiss so hovering the bar (or a rebuild in between) can never
        // leave it stuck on screen past its window.
        duration: const Duration(days: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.primary,
          onPressed: () => cubit.undoLast(),
        ),
      ),
    );
    // Closes this specific snackbar instance (a no-op if it's already gone),
    // rather than `hideCurrentSnackBar()`, which would blindly dismiss
    // whatever snackbar happens to be showing 5s from now — including an
    // unrelated one shown in between if the user dismissed this one early.
    _undoDismissTimer = Timer(ScheduleCubit.undoWindow, controller.close);
  }

  /// One-line affordance hint under the grid — drag / switch / right-click /
  /// tap are invisible until named. Signed off with a quiet DROP mark.
  Widget _gridHint() {
    final hint = context.isDesktop
        ? 'Drag people between shifts · drop a person on another to switch '
              'them · right-click for actions · click a cell for details'
        : 'Tap a shift to manage · long-press a person for actions · '
              'swipe for more days';
    return Row(
      children: [
        const Icon(
          Icons.touch_app_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hint,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        const DropLogo(height: 13, color: AppColors.textTertiary),
      ],
    );
  }

  // ── Insight strip ──────────────────────────────────────────────
  /// Fact chips derived from the roster (open · one-person · double-booked)
  /// plus the pending-swap queue. Clicking a fact chip highlights its slots in
  /// the grid; the swap chip opens the queue. Facts, never quotas — when the
  /// week is clean the strip collapses to a quiet all-clear line.
  Widget _insightStrip(ScheduleInsights insights, ScheduleInsightKind? active) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (insights.allClear)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Week fully staffed · no conflicts',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          )
        else ...[
          if (insights.openCount > 0)
            _insightChip(
              kind: ScheduleInsightKind.open,
              active: active,
              count: insights.openCount,
              label: insights.openCount == 1 ? 'open shift' : 'open shifts',
              dotColor: AppColors.warning,
            ),
          if (insights.onePersonCount > 0)
            _insightChip(
              kind: ScheduleInsightKind.onePerson,
              active: active,
              count: insights.onePersonCount,
              label: insights.onePersonCount == 1
                  ? 'one-person shift'
                  : 'one-person shifts',
            ),
          if (insights.doubleBookedCount > 0)
            _insightChip(
              kind: ScheduleInsightKind.doubleBooked,
              active: active,
              count: insights.doubleBookedCount,
              label: 'double-booked',
              dotColor: AppColors.error,
            ),
        ],
        _swapChip(),
      ],
    );
  }

  Widget _insightChip({
    required ScheduleInsightKind kind,
    required ScheduleInsightKind? active,
    required int count,
    required String label,
    Color? dotColor,
  }) {
    final selected = active == kind;
    return Tooltip(
      message: selected ? 'Clear highlight' : 'Highlight these shifts',
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: () => setState(() => _activeInsight = selected ? null : kind),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSurface : AppColors.darkSurface,
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              color: selected ? AppColors.accentBorder : AppColors.darkBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '$count ',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pending-swap queue chip — replaces the old floating footer card, so swap
  /// management lives on the same line as every other week fact.
  Widget _swapChip() {
    return BlocBuilder<ShiftSwapCubit, ShiftSwapState>(
      builder: (context, state) {
        final count = state.maybeWhen(
          loaded: (swaps, _) => swaps.where((s) => !s.status.isResolved).length,
          orElse: () => 0,
        );
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showSwapQueueSheet(
            context: context,
            currentUid: _user?.uid ?? '',
            showBranch: widget.isAdmin,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.fullAll,
              border: Border.all(color: AppColors.accentBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$count ',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  count == 1 ? 'swap waiting' : 'swaps waiting',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Empty / placeholder states ─────────────────────────────────
  // Brand-led (§9b): the DROP mark leads the empty moments instead of a
  // generic grey glyph.
  Widget _emptySchedule() {
    return DropEmptyState(
      title: 'No schedule for this week yet',
      message: 'Create one to start assigning shifts.',
      action: FilledButton.icon(
        onPressed: () =>
            context.read<ScheduleCubit>().createSchedule(createdBy: _user?.uid),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Schedule'),
      ),
    );
  }
}
