import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/drop_loading_state.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/swap_eligibility.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_view.dart';

/// Employee schedule screen — premium redesign. Two tabs: "My Week" (greeting,
/// today's hero card with shift / manager / team, and the full week list with
/// per-slot Swap actions) and "Swaps". Entrance and refresh both stagger-animate
/// the content sections in with FadeTransition + SlideTransition.
class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user == null) return;
    context.read<ScheduleCubit>().load(branchId: user.branchId ?? '');
    context.read<ShiftSwapCubit>().loadMine(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AdaptiveScaffold(
        title: 'My Schedule',
        subtitle: 'Your week and shift swaps',
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
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2,
          tabs: [
            Tab(text: 'My Week'),
            Tab(text: 'Swaps'),
          ],
        ),
        body: TabBarView(
          children: [
            _MyWeekTab(),
            // Resolve the uid at build time — caching it from the post-frame
            // _load() without setState left it '' until an incidental rebuild,
            // hiding every Accept/Decline/Cancel action on the Swaps tab.
            SwapListView(
              isManager: false,
              currentUid: context.currentUser?.uid ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Week Tab ─────────────────────────────────────────────────────────────

class _MyWeekTab extends StatefulWidget {
  @override
  State<_MyWeekTab> createState() => _MyWeekTabState();
}

class _MyWeekTabState extends State<_MyWeekTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // TabBarView disposes this tab whenever the user visits Swaps and
    // recreates it on return — with the cubit still `loaded`, so the listener
    // below (which only fires on a state CHANGE) never plays the entrance
    // animation and the whole week renders at opacity 0. If the data is
    // already there at mount, show it immediately; the stagger remains for
    // real load/refresh cycles.
    final alreadyLoaded = context.read<ScheduleCubit>().state.maybeWhen(
          loaded: (_, _, _, _, _) => true,
          orElse: () => false,
        );
    if (alreadyLoaded) _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Each section gets its own fade/slide interval within [0,1].
  Animation<double> _fade(double t0, double t1) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(t0, t1, curve: Curves.easeOut),
        ),
      );

  Animation<Offset> _slide(double t0, double t1) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(t0, t1, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScheduleCubit, ScheduleState>(
      listener: (context, state) {
        state.whenOrNull(
          loaded: (_, _, _, _, busy) {
            if (!busy) _ctrl.forward(from: 0);
          },
        );
      },
      builder: (context, state) => state.maybeWhen(
        loading: () => const DropLoadingState(message: 'Loading your week…'),
        loaded: (branchId, weekStart, schedule, members, busy) =>
            _buildList(context, weekStart, schedule, members),
        error: (m) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Text(m,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ),
        ),
        // `initial` (load not kicked off yet, e.g. before the post-frame _load
        // or a momentarily-null user) must never render as a blank screen —
        // show the loader; the app-bar Refresh recovers any stuck state.
        orElse: () => const DropLoadingState(message: 'Loading your week…'),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    DateTime weekStart,
    WeeklyScheduleEntity? schedule,
    List<UserEntity> members,
  ) {
    final user = context.currentUser;
    final uid = user?.uid ?? '';

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurface,
      onRefresh: () => context.read<ScheduleCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          // ── Greeting ────────────────────────────────────────────
          FadeTransition(
            opacity: _fade(0.00, 0.35),
            child: SlideTransition(
              position: _slide(0.00, 0.35),
              child: _GreetingHeader(user: user),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (schedule == null) ...[
            FadeTransition(
              opacity: _fade(0.20, 0.60),
              child: _NoScheduleCard(),
            ),
          ] else ...[
            // ── Today hero card ──────────────────────────────────
            FadeTransition(
              opacity: _fade(0.15, 0.55),
              child: SlideTransition(
                position: _slide(0.15, 0.55),
                child: _TodayHeroCard(
                  schedule: schedule,
                  members: members,
                  uid: uid,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── This Week header ─────────────────────────────────
            FadeTransition(
              opacity: _fade(0.30, 0.60),
              child: SlideTransition(
                position: _slide(0.30, 0.60),
                child: _WeekSectionHeader(weekStart: weekStart),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Week rows — staggered per day ────────────────────
            ...ScheduleDay.values.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final t0 = (0.40 + i * 0.05).clamp(0.0, 0.90);
              final t1 = (t0 + 0.25).clamp(0.0, 1.00);
              return FadeTransition(
                opacity: _fade(t0, t1),
                child: SlideTransition(
                  position: _slide(t0, t1),
                  child: _WeekDayRow(
                    schedule: schedule,
                    members: members,
                    user: user,
                    day: day,
                    weekStart: weekStart,
                    onSwap: (d, s) =>
                        _requestSwap(context, schedule, members, user, d, s),
                  ),
                ),
              );
            }),
          ],
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
    // Exchange model: you may only swap with a coworker on the OPPOSITE shift
    // that same day — they hold the slot you want, you hold theirs. This also
    // enforces "requester ≠ target" and "target slot must exist". Eligibility is
    // "same branch, any role" (the picker doesn't filter by app-role); role/
    // position compatibility is a per-branch policy applied inside the sheet.
    final opposite = shift.opposite;
    final oppositeUids = schedule.employeesFor(day, opposite).toSet();
    final coworkers = members
        .where((u) => u.uid != user.uid && oppositeUids.contains(u.uid))
        .toList();
    if (coworkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'No coworkers on the ${opposite.label} shift to swap with.')),
      );
      return;
    }
    showSwapRequestSheet(
      context: context,
      cubit: context.read<ShiftSwapCubit>(),
      schedule: schedule,
      branchId: schedule.branchId,
      weekStart: schedule.weekStart,
      day: day,
      shift: shift,
      requester: user,
      coworkers: coworkers,
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.user});
  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final name = _firstName(user);
    final date = _dateLabel(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $name 👋', style: AppTypography.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(date,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }

  String _firstName(UserEntity? u) {
    final n = (u?.displayName ?? '').trim();
    if (n.isEmpty) return 'there';
    return n.split(RegExp(r'\s+')).first;
  }

  String _dateLabel(DateTime d) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

// ─── No Schedule Card ────────────────────────────────────────────────────────

class _NoScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
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
          Text(
            'No schedule published for this week yet.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

// ─── Today Hero Card ─────────────────────────────────────────────────────────

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.schedule,
    required this.members,
    required this.uid,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final today = ScheduleDay.today();
    final myShifts = schedule.shiftsFor(uid, today);
    final isOff = myShifts.isEmpty;
    final shift = isOff ? null : myShifts.first;

    // Coworkers on the same shift(s) today.
    final teamUids = <String>{};
    for (final s in myShifts) {
      teamUids.addAll(
        schedule.employeesFor(today, s).where((u) => u != uid),
      );
    }
    final teamUsers = teamUids
        .map((t) => userForUid(t, members))
        .whereType<UserEntity>()
        .toList();

    final managers =
        members.where((m) => m.role.isManager || m.role.isAdmin).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: isOff
              ? AppColors.darkBorder
              : AppColors.primary.withAlpha(70), // ~27% white border
        ),
      ),
      child: Column(
        children: [
          _buildHeader(shift, isOff),
          const Divider(height: 1, color: AppColors.darkBorder),
          _buildTeamRow(teamUsers, managers, isOff),
          const Divider(height: 1, color: AppColors.darkBorder),
          _buildDetailsRow(context, today, shift, teamUsers, managers),
        ],
      ),
    );
  }

  Widget _buildHeader(ScheduleShift? shift, bool isOff) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShiftIconBox(shift: shift),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TODAY pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.fullAll,
                    border: Border.all(
                        color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Text(
                    'TODAY',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isOff ? 'Day Off' : '${shift!.label} Shift',
                  style: AppTypography.h2,
                ),
                if (!isOff) ...[
                  const SizedBox(height: 4),
                  _CountdownRow(shift: shift!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(
    List<UserEntity> team,
    List<UserEntity> managers,
    bool isOff,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manager
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manager', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                if (managers.isEmpty)
                  Text('—', style: AppTypography.body)
                else
                  Row(
                    children: [
                      UserAvatar.fromUser(managers.first, size: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userDisplayName(managers.first),
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _roleLabel(managers.first),
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Working with
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Working with', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                if (team.isEmpty || isOff)
                  Text(isOff ? '—' : 'Just you', style: AppTypography.body)
                else
                  _TeamAvatars(users: team),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsRow(
    BuildContext context,
    ScheduleDay today,
    ScheduleShift? shift,
    List<UserEntity> team,
    List<UserEntity> managers,
  ) {
    return InkWell(
      onTap: shift == null
          ? null
          : () => _showShiftDetails(context, today, shift, team, managers),
      borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.card)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'View Shift Details',
                style: AppTypography.label
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showShiftDetails(
    BuildContext context,
    ScheduleDay day,
    ScheduleShift shift,
    List<UserEntity> team,
    List<UserEntity> managers,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ShiftDetailsSheet(
        day: day,
        shift: shift,
        team: team,
        managers: managers,
      ),
    );
  }

  String _roleLabel(UserEntity u) =>
      u.role.isAdmin ? 'Admin' : 'Store Manager';
}

// ─── Shift Icon Box ───────────────────────────────────────────────────────────

class _ShiftIconBox extends StatelessWidget {
  const _ShiftIconBox({this.shift});
  final ScheduleShift? shift;

  @override
  Widget build(BuildContext context) {
    final icon = shift == null
        ? Icons.do_not_disturb_on_outlined
        : (shift == ScheduleShift.morning
            ? Icons.wb_sunny_rounded
            : Icons.nightlight_rounded);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Icon(icon, color: AppColors.textSecondary, size: 26),
    );
  }
}

// ─── Countdown Row (time + "In X min" pill) ───────────────────────────────────

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({required this.shift});
  final ScheduleShift shift;

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown(shift);
    return Row(
      children: [
        const Icon(Icons.access_time_rounded,
            size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          shift.timeRange,
          style: AppTypography.caption
              .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        if (countdown != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.fullAll,
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Text(
              countdown,
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String? _countdown(ScheduleShift shift) {
    final startStr = shift.timeRange.split('–').first.trim();
    final parts = startStr.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, h, m);
    final diff = start.difference(now);
    if (diff.isNegative || diff.inMinutes == 0) return null;
    if (diff.inMinutes < 120) return 'In ${diff.inMinutes}m';
    return null;
  }
}

// ─── Team Avatars (with first names below) ────────────────────────────────────

class _TeamAvatars extends StatelessWidget {
  const _TeamAvatars({required this.users});
  final List<UserEntity> users;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const step = size * 0.62;
    final shown = users.length > 3 ? users.take(3).toList() : users;
    final overflow = users.length - shown.length;
    final discCount = shown.length + (overflow > 0 ? 1 : 0);
    final totalWidth = size + (discCount - 1) * step;

    final overflowNames = overflow > 0
        ? users.skip(3).map((u) => userDisplayName(u).split(' ').first).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: totalWidth,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ...shown.asMap().entries.map((e) => Positioned(
                    left: e.key * step,
                    child: UserAvatar.fromUser(e.value,
                        size: size, ringColor: AppColors.darkSurface),
                  )),
              if (overflow > 0)
                Positioned(
                  left: shown.length * step,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkSurfaceElevated,
                      border: Border.all(
                          color: AppColors.darkSurface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflow',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: size * 0.34,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _namesSummary(shown, overflowNames),
          style: AppTypography.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _namesSummary(List<UserEntity> shown, List<String> extra) {
    final names = shown.map((u) => userDisplayName(u).split(' ').first).toList();
    if (extra.isEmpty) return names.join(', ');
    return '${names.join(', ')}, +${extra.length} more';
  }
}

// ─── Shift Details Bottom Sheet ───────────────────────────────────────────────

class _ShiftDetailsSheet extends StatelessWidget {
  const _ShiftDetailsSheet({
    required this.day,
    required this.shift,
    required this.team,
    required this.managers,
  });

  final ScheduleDay day;
  final ScheduleShift shift;
  final List<UserEntity> team;
  final List<UserEntity> managers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.lg, AppSpacing.pagePadding, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: AppRadius.fullAll,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _ShiftIconBox(shift: shift),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${shift.label} Shift', style: AppTypography.h3),
                  const SizedBox(height: 2),
                  Text(shift.timeRange,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (managers.isNotEmpty) ...[
            Text('Manager', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            _MemberTile(user: managers.first),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (team.isNotEmpty) ...[
            Text('Team on this shift', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            ...team.map((u) => _MemberTile(user: u)),
          ] else
            Text('You are the only one on this shift.',
                style: AppTypography.body),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.user});
  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          UserAvatar.fromUser(user, size: 36),
          const SizedBox(width: AppSpacing.md),
          Text(userDisplayName(user), style: AppTypography.label),
        ],
      ),
    );
  }
}

// ─── Week Section Header ──────────────────────────────────────────────────────

class _WeekSectionHeader extends StatelessWidget {
  const _WeekSectionHeader({required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range = _range(weekStart, weekEnd);
    return Row(
      children: [
        Text('This Week', style: AppTypography.h3),
        const Spacer(),
        Text(range,
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }

  String _range(DateTime s, DateTime e) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return s.month == e.month
        ? '${s.day} – ${e.day} ${m[e.month - 1]}'
        : '${s.day} ${m[s.month - 1]} – ${e.day} ${m[e.month - 1]}';
  }
}

// ─── Week Day Row ─────────────────────────────────────────────────────────────

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.schedule,
    required this.members,
    required this.user,
    required this.day,
    required this.weekStart,
    required this.onSwap,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final UserEntity? user;
  final ScheduleDay day;
  final DateTime weekStart;
  final void Function(ScheduleDay, ScheduleShift) onSwap;

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid ?? '';
    final shifts = schedule.shiftsFor(uid, day);
    final isToday = day == ScheduleDay.today();
    // weekStart is Sunday = index 0; day.index maps directly.
    final dayDate = weekStart.add(Duration(days: day.index));

    if (shifts.isEmpty) {
      return _buildRow(context, null, isToday, dayDate);
    }

    // Multiple shifts on same day → one row each.
    return Column(
      children: shifts
          .map((s) => _buildRow(context, s, isToday, dayDate))
          .toList(),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ScheduleShift? shift,
    bool isToday,
    DateTime dayDate,
  ) {
    final isOff = shift == null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: isToday ? AppColors.darkSurfaceElevated : AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: isToday
              ? AppColors.primary.withAlpha(40)
              : AppColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          // ── Day chip ──────────────────────────────────────────
          _DayChip(day: day, date: dayDate, isToday: isToday),
          const SizedBox(width: AppSpacing.md),

          // ── Shift icon circle ─────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Icon(
              isOff
                  ? Icons.remove_circle_outline_rounded
                  : (shift == ScheduleShift.morning
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined),
              size: 16,
              color: isOff ? AppColors.textTertiary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // ── Shift name + time ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOff ? 'Off' : '${shift.label} Shift',
                  style: AppTypography.label.copyWith(
                    color: isOff
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
                if (!isOff)
                  Text(shift.timeRange, style: AppTypography.caption),
              ],
            ),
          ),

          // ── Action: Swap / Today / — ──────────────────────────
          if (isOff)
            const SizedBox(
              width: 40,
              child: Text('—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textTertiary, fontSize: 16)),
            )
          else if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                'Today',
                style: AppTypography.caption.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (_canSwap(shift))
            GestureDetector(
              onTap: () => onSwap(day, shift),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: AppRadius.fullAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 15, color: AppColors.textPrimary),
                    const SizedBox(width: 5),
                    Text(
                      'Swap',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Past / in-progress shift — not swappable, so don't offer it.
            SizedBox(
              width: 44,
              child: Text('Past',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ),
        ],
      ),
    );
  }

  /// A shift is swappable only while its start is still in the future — keep the
  /// offered action in lock-step with [SwapEligibility] (no swap on a past slot).
  bool _canSwap(ScheduleShift? shift) =>
      shift != null && SwapEligibility.isRequestable(weekStart, day, shift);
}

// ─── Day Chip ─────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.date,
    required this.isToday,
  });

  final ScheduleDay day;
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day.shortLabel,
            style: AppTypography.caption.copyWith(
              color: isToday ? AppColors.textSecondary : AppColors.textTertiary,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.smAll,
                  )
                : null,
            child: Text(
              '${date.day}',
              style: AppTypography.label.copyWith(
                color: isToday ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
