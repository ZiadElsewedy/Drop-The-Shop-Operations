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
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_state.dart';
import 'package:fbro/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:fbro/features/schedule/domain/schedule_week.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:fbro/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The weekly-schedule editor body (Phase 7), shared by the manager (own branch)
/// and admin (any branch) screens. Renders a week selector and the 7-day roster
/// with Morning / Night slots; managers/admins assign and remove employees.
/// Hosted inside a Scaffold provided by the page (so it can sit under a TabBar).
class ManagerScheduleView extends StatefulWidget {
  const ManagerScheduleView({super.key, required this.isAdmin});

  /// Admin = pick any branch (branch selector shown). Manager = own branch fixed.
  final bool isAdmin;

  @override
  State<ManagerScheduleView> createState() => _ManagerScheduleViewState();
}

class _ManagerScheduleViewState extends State<ManagerScheduleView> {
  UserEntity? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    _user = context.currentUser;
    if (widget.isAdmin) {
      // Load the branch list for the selector; wait for a branch pick to load.
      context.read<BranchCubit>().load();
      context.read<ScheduleCubit>().load(branchId: '');
    } else {
      context.read<ScheduleCubit>().load(branchId: _user?.branchId ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScheduleCubit, ScheduleState>(
      listener: (context, state) =>
          state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
      builder: (context, state) => state.maybeWhen(
        loading: () => const Center(child: CircularProgressIndicator()),
        loaded: (branchId, weekStart, schedule, members, busy) =>
            _body(branchId, weekStart, schedule, members, busy),
        orElse: () => const SizedBox.shrink(),
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
        if (widget.isAdmin) _branchSelector(branchId),
        _weekSelector(weekStart, cubit),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.refresh(),
            child: _content(branchId, schedule, members),
          ),
        ),
      ],
    );
  }

  // ── Selectors ──────────────────────────────────────────────────
  Widget _branchSelector(String branchId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.md, AppSpacing.pagePadding, 0),
      child: BlocBuilder<BranchCubit, BranchState>(
        builder: (context, state) {
          final branches = state.maybeWhen(
            loaded: (b, _) => b,
            orElse: () => const <BranchEntity>[],
          );
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: branchId.isEmpty ? null : branchId,
                isExpanded: true,
                hint: Text('Select a branch', style: AppTypography.body),
                dropdownColor: AppColors.darkSurfaceElevated,
                borderRadius: AppRadius.cardAll,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary),
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
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
      ),
    );
  }

  Widget _weekSelector(DateTime weekStart, ScheduleCubit cubit) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppColors.textSecondary),
            onPressed: cubit.previousWeek,
            tooltip: 'Previous week',
          ),
          Expanded(
            child: Column(
              children: [
                Text('Week of', style: AppTypography.caption),
                Text(ScheduleWeek.rangeLabel(weekStart),
                    style: AppTypography.label),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
            onPressed: cubit.nextWeek,
            tooltip: 'Next week',
          ),
        ],
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
      return _centeredMessage(
          Icons.store_mall_directory_outlined, 'Select a branch to view its schedule.');
    }
    if (schedule == null) {
      return _emptySchedule();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, 0,
          AppSpacing.pagePadding, AppSpacing.xxxl),
      children: [
        for (final day in ScheduleDay.values)
          _dayCard(day, schedule, members),
      ],
    );
  }

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

  Widget _dayCard(
    ScheduleDay day,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
  ) {
    final isToday = ScheduleDay.today() == day;
    final covered = {
      for (final shift in ScheduleShift.values)
        ...schedule.employeesFor(day, shift),
    }.length;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardAll,
        border: Border.all(
            color: isToday ? AppColors.primary : AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(day.label, style: AppTypography.label),
              if (isToday) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Today',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.primary)),
                ),
              ],
              const Spacer(),
              // Coverage indicator.
              Icon(
                covered == 0
                    ? Icons.error_outline_rounded
                    : Icons.people_alt_outlined,
                size: 14,
                color:
                    covered == 0 ? AppColors.warning : AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text('$covered',
                  style: AppTypography.caption.copyWith(
                    color: covered == 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final shift in ScheduleShift.values) ...[
            _shiftRow(day, shift, schedule, members),
            if (shift != ScheduleShift.values.last)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _shiftRow(
    ScheduleDay day,
    ScheduleShift shift,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
  ) {
    final uids = schedule.employeesFor(day, shift);
    final isMorning = shift == ScheduleShift.morning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Shift badge.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMorning
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined,
                    size: 14,
                    color: isMorning ? AppColors.warning : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(shift.label, style: AppTypography.labelSmall),
                ],
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _pickEmployee(day, shift, schedule, members),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTypography.caption,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (uids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text('No one assigned', style: AppTypography.caption),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final uid in uids)
                _employeeChip(
                    uid,
                    nameForUid(uid, members),
                    userForUid(uid, members),
                    () =>
                        context.read<ScheduleCubit>().remove(day, shift, uid)),
            ],
          ),
      ],
    );
  }

  Widget _employeeChip(
      String uid, String name, UserEntity? user, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.only(left: 5, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user != null)
            UserAvatar.fromUser(user,
                size: 22, ringColor: AppColors.darkSurfaceElevated)
          else
            UserAvatar(
                name: name,
                size: 22,
                ringColor: AppColors.darkSurfaceElevated),
          const SizedBox(width: 6),
          Text(name, style: AppTypography.caption),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _pickEmployee(
    ScheduleDay day,
    ScheduleShift shift,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
  ) {
    final employees = members.where((u) => u.role.isEmployee).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pagePadding,
          right: AppSpacing.pagePadding,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${day.label} · ${shift.label}', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
            if (employees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No employees in this branch yet.',
                    style: AppTypography.bodySmall),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: employees.length,
                  itemBuilder: (context, i) {
                    final u = employees[i];
                    final assigned =
                        schedule.isAssigned(u.uid, day, shift);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar.fromUser(u, size: 40),
                      title: Text(userDisplayName(u), style: AppTypography.label),
                      subtitle: Text(u.email, style: AppTypography.caption),
                      trailing: assigned
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 18)
                          : const Icon(Icons.add_rounded,
                              color: AppColors.textTertiary, size: 18),
                      onTap: () {
                        if (!assigned) {
                          context
                              .read<ScheduleCubit>()
                              .assign(day, shift, u.uid);
                        }
                        Navigator.of(sheetCtx).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
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
