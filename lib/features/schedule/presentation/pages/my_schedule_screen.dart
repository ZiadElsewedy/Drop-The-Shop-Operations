import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/schedule_day.dart';
import 'package:fbro/core/enums/schedule_shift.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:fbro/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:fbro/features/schedule/presentation/widgets/swap_view.dart';

/// Employee schedule screen (Phase 7). Two tabs: "My Week" (today's shift, the
/// team working alongside them, their manager, and their week with a per-slot
/// "Request swap" action) and "Swaps" (their swap requests). Read-only on the
/// schedule itself — only managers/admins edit (enforced by `firestore.rules`).
class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  UserEntity? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user == null) return;
    _user = user;
    context.read<ScheduleCubit>().load(branchId: user.branchId ?? '');
    context.read<ShiftSwapCubit>().loadMine(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          title: Text('My Schedule', style: AppTypography.h3),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'My Week'),
              Tab(text: 'Swaps'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyWeekTab(),
            SwapListView(isManager: false, currentUid: _user?.uid ?? ''),
          ],
        ),
      ),
    );
  }
}

class _MyWeekTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleCubit, ScheduleState>(
      builder: (context, state) => state.maybeWhen(
        loading: () => const Center(child: CircularProgressIndicator()),
        loaded: (branchId, weekStart, schedule, members, busy) =>
            _content(context, schedule, members),
        error: (m) => Center(
            child: Text(m,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.error))),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WeeklyScheduleEntity? schedule,
    List<UserEntity> members,
  ) {
    final user = context.currentUser;
    final uid = user?.uid ?? '';
    return RefreshIndicator(
      onRefresh: () => context.read<ScheduleCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          if (schedule == null)
            _noSchedule()
          else ...[
            _todayCard(context, schedule, members, uid),
            const SizedBox(height: AppSpacing.xl),
            Text('My week', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),
            ..._weekRows(context, schedule, members, user),
          ],
        ],
      ),
    );
  }

  Widget _noSchedule() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text('No schedule published for this week yet.',
              textAlign: TextAlign.center, style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _todayCard(
    BuildContext context,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    String uid,
  ) {
    final today = ScheduleDay.today();
    final myShifts = schedule.shiftsFor(uid, today);

    // Coworkers across all of my shifts today (distinct, excluding me).
    final team = <String>{};
    for (final shift in myShifts) {
      team.addAll(schedule.employeesFor(today, shift).where((u) => u != uid));
    }

    final manager = members.where((m) => m.role.isManager).toList();
    final teamUsers = [
      for (final t in team)
        if (userForUid(t, members) != null) userForUid(t, members)!,
    ];

    final shiftLabel = myShifts.isEmpty
        ? 'Off today'
        : myShifts.map((s) => s.label).join(' & ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today · ${today.label}', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                myShifts.isEmpty
                    ? Icons.do_not_disturb_on_outlined
                    : (myShifts.contains(ScheduleShift.morning)
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined),
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(shiftLabel, style: AppTypography.h3),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Working with', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          if (teamUsers.isEmpty)
            Text(myShifts.isEmpty ? '—' : 'Just you',
                style: AppTypography.bodySmall)
          else
            Row(
              children: [
                AvatarStack(users: teamUsers, size: 30),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                      teamUsers.map(userDisplayName).join(', '),
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Manager', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          if (manager.isEmpty)
            Text('—', style: AppTypography.bodySmall)
          else
            Row(
              children: [
                UserAvatar.fromUser(manager.first, size: 30),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(userDisplayName(manager.first),
                      style: AppTypography.bodySmall),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _weekRows(
    BuildContext context,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    UserEntity? user,
  ) {
    final uid = user?.uid ?? '';
    final rows = <Widget>[];
    for (final day in ScheduleDay.values) {
      final shifts = schedule.shiftsFor(uid, day);
      if (shifts.isEmpty) continue;
      for (final shift in shifts) {
        rows.add(_slotRow(context, schedule, members, user, day, shift));
      }
    }
    if (rows.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text("You're not scheduled this week.",
            style: AppTypography.bodySmall),
      ));
    }
    return rows;
  }

  Widget _slotRow(
    BuildContext context,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    UserEntity? user,
    ScheduleDay day,
    ScheduleShift shift,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(
            shift == ScheduleShift.morning
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_outlined,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('${day.label} · ${shift.label}',
                style: AppTypography.label),
          ),
          TextButton.icon(
            onPressed: () => _requestSwap(
                context, schedule, members, user, day, shift),
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Swap'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }

  void _requestSwap(
    BuildContext context,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    UserEntity? user,
    ScheduleDay day,
    ScheduleShift shift,
  ) {
    if (user == null) return;
    final coworkers = members.where((u) => u.role.isEmployee).toList();
    if (coworkers.length < 2) {
      AppSnackbar.error(context, 'No coworkers available to swap with.');
      return;
    }
    showSwapRequestSheet(
      context: context,
      cubit: context.read<ShiftSwapCubit>(),
      branchId: schedule.branchId,
      weekStart: schedule.weekStart,
      day: day,
      shift: shift,
      requester: user,
      coworkers: coworkers,
    );
  }
}
