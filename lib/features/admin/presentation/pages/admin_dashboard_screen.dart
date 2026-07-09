import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/action_card.dart';
import 'package:drop/core/widgets/admin_section_header.dart';
import 'package:drop/core/widgets/app_shell.dart';
import 'package:drop/core/widgets/attention_tile.dart';
import 'package:drop/core/widgets/command_palette.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_state.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_alert_card.dart'
    show showSwapQueueSheet;
import 'package:drop/features/statistics/domain/entities/statistics_entity.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_metrics.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/filtered_tasks_screen.dart';
import 'package:drop/features/task/presentation/widgets/live_status_border.dart';
import 'package:drop/features/task/presentation/widgets/recent_activity_feed.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// Admin Home — an operations **command center** (DROP Design System V2). Ranked
/// as a progressive-disclosure ladder so the admin instantly sees *what needs
/// attention right now*, then today's health, then recent activity — never "here
/// is every row in the database".
///
/// Hierarchy: **Hero** (greeting · scope · one Create Task CTA) → **Needs
/// attention** (the dominant layer: pending review · overdue · unassigned ·
/// rejected · swaps, each a filtered drill) → **Today** (light metrics) →
/// **Recent activity** (clean vertical feed, no filters) → **Operations**
/// (requests · cases · schedule digest) → Quick actions / Manage / Branch pulse.
///
/// Every visual is a reusable V2 primitive (`PageHero`, `AttentionTile`,
/// `StatStrip`, `ActivityCard`) — this screen only arranges them and derives the
/// data, so the same language carries to every future module. It stays **live**:
/// each section is a scoped `BlocSelector` over the streams, so counters update
/// without a manual refresh, and a task emit rebuilds only the section it moves.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// A refresh is in flight — drives the header Sync control's spinner.
  bool _syncing = false;

  /// When the live sources were last (re)pulled — drives "Synced 3m ago".
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Refresh the live sources that feed the dashboard, tracking a single
  /// [_syncing]/[_lastSynced] pair so the header **Sync** button can show a
  /// spinner and how fresh the numbers are. The surface stays reactive without
  /// this — Sync is a manual escape hatch, not the update mechanism.
  Future<void> _load({bool force = false}) async {
    final user = context.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _syncing = true);
    final startedAt = DateTime.now();
    try {
      await Future.wait([
        context.read<StatisticsCubit>().load(user, forceRefresh: force),
        // The all-branches task stream powers Needs Attention + the activity
        // feed. TaskCubit.load is self-guarding (no-op if already streaming this
        // user unless forced), so a revisit doesn't re-subscribe.
        context.read<TaskCubit>().load(user, forceRefresh: force),
        // Live scopes for the swap tile + the operations digest.
        context.read<ShiftSwapCubit>().loadAll(force: force),
        context.read<RequestsListCubit>().load(user, forceRefresh: force),
        context.read<CaseListCubit>().load(user, forceRefresh: force),
      ]);
      // On an explicit sync, keep the spin perceptible even when every source
      // answered from cache in a few milliseconds — otherwise the tap feels dead.
      if (force) {
        final rest =
            const Duration(milliseconds: 650) -
            DateTime.now().difference(startedAt);
        if (rest > Duration.zero) await Future<void>.delayed(rest);
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _lastSynced = DateTime.now();
        });
      }
    }
  }

  Widget _syncButton({bool compact = false}) => _SyncButton(
    syncing: _syncing,
    lastSynced: _lastSynced,
    onSync: () => _load(force: true),
    compact: compact,
  );

  @override
  Widget build(BuildContext context) {
    // No top-level cubit subscription: the scroll scaffold + static sections
    // build once. Each data-driven section subscribes to only what it needs via
    // a scoped selector, so a stream emit no longer rebuilds the whole screen.
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: context.isDesktop ? _desktop(context) : _mobile(context),
    );
  }

  // Stable keys + a fixed per-section stagger so the entrance plays once and
  // never replays when a conditional section appears. Honours reduced motion.
  Widget _sec(String id, int index, Widget child) {
    if (MediaQuery.of(context).disableAnimations) {
      return KeyedSubtree(key: ValueKey('admin-sec-$id'), child: child);
    }
    return EntranceFade(
      key: ValueKey('admin-sec-$id'),
      delay: staggerDelay(index),
      child: child,
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────
  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _scopeLine(StatisticsEntity? s, int running) {
    if (s == null) {
      return running > 0 ? '$running running now' : 'Operations overview';
    }
    final b =
        '${s.totalBranches} ${s.totalBranches == 1 ? 'branch' : 'branches'}';
    final e =
        '${s.totalEmployees} ${s.totalEmployees == 1 ? 'employee' : 'employees'}';
    return '$b · $e · $running running';
  }

  void _createTask() => startNewTaskFlow(
    context: context,
    cubit: context.read<TaskCubit>(),
    isAdmin: true,
    defaultBranchId: '',
  );

  Widget _hero() {
    final name = context.currentUser?.displayName;
    final first = (name != null && name.trim().isNotEmpty)
        ? name.trim().split(' ').first
        : 'Admin';
    final date = AppDateFormatter.weekdayDayMonth(DateTime.now());
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final s = statsState.maybeWhen(loaded: (s) => s, orElse: () => null);
        return BlocSelector<TaskCubit, TaskState, int>(
          selector: (state) => runningNowCount(
            state.maybeWhen(loaded: (t, _, _, _, _) => t, orElse: () => const []),
          ),
          builder: (context, running) => PageHero(
            eyebrow: date,
            title: '$_salutation, $first',
            subtitle: _scopeLine(s, running),
            subtitleIcon: Icons.public_rounded,
            primaryAction: _PrimaryCta(
              icon: Icons.add_rounded,
              label: 'Create Task',
              onTap: _createTask,
            ),
            trailing: context.isDesktop
                ? [_syncButton(), _CommandHint()]
                : [_syncButton(compact: true)],
          ),
        );
      },
    );
  }

  // ── Needs attention (the dominant layer) ─────────────────────────
  Widget _needsAttention() {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final staffing = statsState.maybeWhen(
          loaded: (s) => s.branchesWithoutManagers,
          orElse: () => 0,
        );
        return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
          selector: (state) => state.maybeWhen(
            loaded: (swaps, _) =>
                swaps.where((s) => !s.status.isResolved).length,
            orElse: () => 0,
          ),
          builder: (context, swaps) {
            return BlocSelector<TaskCubit, TaskState, (int, int, int, int)>(
              selector: (state) {
                final tasks = state.maybeWhen(
                  loaded: (t, _, _, _, _) => t,
                  orElse: () => const <TaskEntity>[],
                );
                final now = DateTime.now();
                return (
                  overdueCount(tasks, now),
                  reviewCount(tasks),
                  unassignedCount(tasks, now),
                  rejectedCount(tasks),
                );
              },
              builder: (context, c) {
                final (overdue, reviews, unassigned, rejected) = c;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (staffing > 0) ...[
                      _StaffingAlert(
                        branchesWithoutManagers: staffing,
                        onTap: () => context.push(RouteNames.adminManagers),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _attentionGrid(
                      reviews: reviews,
                      overdue: overdue,
                      unassigned: unassigned,
                      rejected: rejected,
                      swaps: swaps,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Push a reusable filtered task list (title + predicate) on the caller's
  /// navigator, so Back returns to the dashboard exactly where it was.
  void _openFiltered(String title, TaskFeedFilter filter, {String? empty}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilteredTasksScreen(
          title: title,
          filter: filter,
          emptyMessage: empty ?? 'Nothing needs attention here right now.',
        ),
      ),
    );
  }

  void _openSwaps() => showSwapQueueSheet(
    context: context,
    currentUid: context.currentUser?.uid ?? '',
    showBranch: true,
  );

  Widget _attentionGrid({
    required int reviews,
    required int overdue,
    required int unassigned,
    required int rejected,
    required int swaps,
  }) {
    // Exactly one tile — the most urgent with work — carries the living border;
    // the rest stay static so the eye lands on the one that matters (calm).
    final liveKey = overdue > 0
        ? 'overdue'
        : reviews > 0
        ? 'reviews'
        : rejected > 0
        ? 'rejected'
        : unassigned > 0
        ? 'unassigned'
        : swaps > 0
        ? 'swaps'
        : '';
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget wrap(String key, Color accent, Widget tile) {
      if (key != liveKey || reduceMotion) return tile;
      final overdueTone = accent == AppColors.error;
      return LiveStatusBorder(
        color: overdueTone ? const Color(0xFFFB923C) : kLivingBorderAccent,
        pulse: overdueTone,
        speed: 1.1,
        borderRadius: AttentionTile.radius,
        child: tile,
      );
    }

    return ResponsiveCardGrid(
      maxItemWidth: 250,
      children: [
        wrap(
          'reviews',
          AppColors.warning,
          AttentionTile(
            icon: Icons.rate_review_outlined,
            label: 'Pending review',
            sublabel: 'Approve or send back',
            count: reviews,
            accent: AppColors.warning,
            onTap: () => context.push(RouteNames.adminReview),
          ),
        ),
        wrap(
          'overdue',
          AppColors.error,
          AttentionTile(
            icon: Icons.event_busy_outlined,
            label: 'Overdue',
            sublabel: 'Past the deadline',
            count: overdue,
            accent: AppColors.error,
            onTap: () => _openFiltered(
              'Overdue',
              const TaskFeedFilter(preset: FeedPreset.overdue),
              empty: 'No overdue work. Nicely done.',
            ),
          ),
        ),
        wrap(
          'unassigned',
          AppColors.warning,
          AttentionTile(
            icon: Icons.person_off_outlined,
            label: 'Unassigned',
            sublabel: 'Needs an owner',
            count: unassigned,
            accent: AppColors.warning,
            onTap: () => _openFiltered(
              'Unassigned',
              const TaskFeedFilter(preset: FeedPreset.unassigned),
              empty: 'Every task has an owner.',
            ),
          ),
        ),
        wrap(
          'rejected',
          AppColors.error,
          AttentionTile(
            icon: Icons.replay_rounded,
            label: 'Sent back',
            sublabel: 'Rejected / rework',
            count: rejected,
            accent: AppColors.error,
            onTap: () => _openFiltered(
              'Sent back',
              const TaskFeedFilter(status: TaskStatus.rejected),
              empty: 'Nothing has been sent back.',
            ),
          ),
        ),
        wrap(
          'swaps',
          AppColors.warning,
          AttentionTile(
            icon: Icons.swap_horiz_rounded,
            label: 'Swap requests',
            sublabel: 'Review shift swaps',
            count: swaps,
            accent: AppColors.warning,
            onTap: _openSwaps,
          ),
        ),
      ],
    );
  }

  // ── Today (light metrics) ────────────────────────────────────────
  Widget _today() {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final s = statsState.maybeWhen(loaded: (s) => s, orElse: () => null);
        return BlocSelector<TaskCubit, TaskState, (int, int, int)>(
          selector: (state) {
            final tasks = state.maybeWhen(
              loaded: (t, _, _, _, _) => t,
              orElse: () => const <TaskEntity>[],
            );
            final now = DateTime.now();
            return (
              runningNowCount(tasks),
              overdueCount(tasks, now),
              dueSoonCount(tasks, now),
            );
          },
          builder: (context, c) {
            final (running, overdue, dueSoon) = c;
            final rate = approvalRatePct(
              approved: s?.completedTasks ?? 0,
              rejected: s?.rejectedTasks ?? 0,
            );
            return StatStrip(
              stats: [
                Stat(label: 'Completed today', value: '${s?.completedTasksToday ?? 0}'),
                Stat(label: 'Running now', value: '$running'),
                Stat(
                  label: 'Due soon',
                  value: '$dueSoon',
                  tone: dueSoon > 0 ? AppColors.warning : null,
                ),
                Stat(
                  label: 'Delayed',
                  value: '$overdue',
                  tone: overdue > 0 ? AppColors.error : null,
                ),
                Stat(label: 'Approval rate', value: rate == null ? '—' : '$rate%'),
              ],
            );
          },
        );
      },
    );
  }

  // ── Operations digest (requests · cases · schedule) ──────────────
  Widget _digest() {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final s = statsState.maybeWhen(loaded: (s) => s, orElse: () => null);
        return BlocSelector<RequestsListCubit, RequestsListState, int>(
          selector: (state) => state.maybeMap(
            loaded: (l) => l.requests.where((r) => r.status.isPending).length,
            orElse: () => 0,
          ),
          builder: (context, pendingReq) {
            return BlocSelector<CaseListCubit, CaseListState, int>(
              selector: (state) => state.maybeMap(
                loaded: (l) => l.cases.where((c) => c.status.isActive).length,
                orElse: () => 0,
              ),
              builder: (context, activeCases) {
                final scheduled = s?.branchesWithSchedule ?? 0;
                final totalBranches = s?.totalBranches ?? 0;
                return GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      _DigestRow(
                        icon: Icons.assignment_turned_in_outlined,
                        label: 'Pending requests',
                        value: '$pendingReq',
                        accent: pendingReq > 0
                            ? AppColors.warning
                            : AppColors.textTertiary,
                        onTap: () => context.push(RouteNames.requests),
                      ),
                      const Divider(color: AppColors.darkBorder, height: 1),
                      _DigestRow(
                        icon: Icons.forum_outlined,
                        label: 'Active cases',
                        value: '$activeCases',
                        accent: activeCases > 0
                            ? AppColors.warning
                            : AppColors.textTertiary,
                        onTap: () => context.push(RouteNames.cases),
                      ),
                      const Divider(color: AppColors.darkBorder, height: 1),
                      _DigestRow(
                        icon: Icons.calendar_view_week_outlined,
                        label: 'Schedule coverage',
                        value: '$scheduled/$totalBranches',
                        accent: AppColors.textSecondary,
                        onTap: () => context.push(RouteNames.adminSchedule),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Quick actions ────────────────────────────────────────────────
  Widget _quickActions({bool compact = false}) {
    return _grid(maxItemWidth: compact ? 180 : 300, [
      ActionCard(
        icon: Icons.assignment_add,
        title: 'New Task',
        onTap: _createTask,
      ),
      ActionCard(
        icon: Icons.add_business_outlined,
        title: 'Add Branch',
        onTap: () => context.push(RouteNames.adminBranches),
      ),
      ActionCard(
        icon: Icons.person_add_alt_1_outlined,
        title: 'New Account',
        onTap: () => context.push(RouteNames.adminCreateAccount),
      ),
      ActionCard(
        icon: Icons.supervisor_account_outlined,
        title: 'Add Manager',
        onTap: () => context.push(RouteNames.adminManagers),
      ),
    ]);
  }

  // ── Manage (module directory) ────────────────────────────────────
  Widget _manage({bool compact = false}) {
    return _grid(maxItemWidth: compact ? 400 : 300, [
      ActionCard(
        icon: Icons.fact_check_outlined,
        title: 'Tasks',
        subtitle: 'All branches',
        secondary: true,
        onTap: () => context.push(RouteNames.adminTasks),
      ),
      ActionCard(
        icon: Icons.calendar_view_week_outlined,
        title: 'Schedules',
        subtitle: 'Any branch',
        secondary: true,
        onTap: () => context.push(RouteNames.adminSchedule),
      ),
      ActionCard(
        icon: Icons.groups_outlined,
        title: 'Employees',
        subtitle: 'Manage staff',
        secondary: true,
        onTap: () => context.push(RouteNames.adminEmployees),
      ),
      ActionCard(
        icon: Icons.insights_outlined,
        title: 'Analytics',
        subtitle: 'Full metrics',
        secondary: true,
        onTap: () => context.push(RouteNames.adminAnalytics),
      ),
    ]);
  }

  Widget _grid(List<Widget> cards, {double maxItemWidth = 300}) {
    return ResponsiveCardGrid(maxItemWidth: maxItemWidth, children: cards);
  }

  // ── Layouts ──────────────────────────────────────────────────────
  Widget _activityHeader() => AdminSectionHeader(
    title: 'Recent activity',
    subtitle: 'Every branch, live',
    actionLabel: 'See all',
    onAction: () => context.push(RouteNames.adminTasks),
  );

  Widget _mobile(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    return ListView(
      key: const PageStorageKey('admin-dashboard-mobile'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        sec('hero', _hero()),
        const SizedBox(height: AppSpacing.xl),
        sec(
          'attn-h',
          const AdminSectionHeader(
            title: 'Needs attention',
            subtitle: 'Act on these first',
          ),
        ),
        sec('attn', _needsAttention()),
        const SizedBox(height: AppSpacing.xl),
        sec('today-h', const AdminSectionHeader(title: 'Today')),
        sec('today', _today()),
        const SizedBox(height: AppSpacing.xl),
        sec('activity-h', _activityHeader()),
        sec('activity', const RecentActivityFeed()),
        const SizedBox(height: AppSpacing.xl),
        sec('digest-h', const AdminSectionHeader(title: 'Operations')),
        sec('digest', _digest()),
        const SizedBox(height: AppSpacing.xl),
        sec('qa-h', const AdminSectionHeader(title: 'Quick actions')),
        sec('qa', _quickActions()),
        const SizedBox(height: AppSpacing.xl),
        sec('manage-h', const AdminSectionHeader(title: 'Manage')),
        sec('manage', _manage()),
      ],
    );
  }

  /// Executive desktop arrangement: the operational story (Needs attention →
  /// today → recent activity) reads down the wide main column; the launch
  /// surfaces (operations digest · quick actions · manage · branch pulse) sit in
  /// a fixed right rail, always in view.
  Widget _desktop(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    return ListView(
      key: const PageStorageKey('admin-dashboard-desktop'),
      padding: const EdgeInsets.fromLTRB(40, AppSpacing.lg, 40, AppSpacing.xxxl),
      children: [
        sec('hero', _hero()),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sec(
                    'attn-h',
                    const AdminSectionHeader(
                      title: 'Needs attention',
                      subtitle: 'Act on these first',
                    ),
                  ),
                  sec('attn', _needsAttention()),
                  const SizedBox(height: AppSpacing.xl),
                  sec('today-h', const AdminSectionHeader(title: 'Today')),
                  sec('today', _today()),
                  const SizedBox(height: AppSpacing.xl),
                  sec('activity-h', _activityHeader()),
                  sec('activity', const RecentActivityFeed()),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(
              width: 330,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sec('digest-h', const AdminSectionHeader(title: 'Operations')),
                  sec('digest', _digest()),
                  const SizedBox(height: AppSpacing.xl),
                  sec('qa-h', const AdminSectionHeader(title: 'Quick actions')),
                  sec('qa', _quickActions(compact: true)),
                  const SizedBox(height: AppSpacing.xl),
                  sec('manage-h', const AdminSectionHeader(title: 'Manage')),
                  sec('manage', _manage(compact: true)),
                  const SizedBox(height: AppSpacing.xl),
                  sec('pulse', const _BranchPulse()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Primary CTA ────────────────────────────────────────────────────

/// The single, prominent primary action of the hero — a filled monochrome
/// button (white accent · dark label). The V2 "one primary action" rule: every
/// module hero has at most one of these. It carries a soft key-light shadow so
/// it reads as *the* action, and responds to hover (a whisper of lift) and press
/// (a subtle scale) — the tactile feedback of a premium control.
class _PrimaryCta extends StatefulWidget {
  const _PrimaryCta({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lifted = _hovered && !reduceMotion;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
              transformAlignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: lifted ? AppColors.accentHover : AppColors.accent,
                borderRadius: AppRadius.buttonAll,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withAlpha(lifted ? 90 : 55),
                    blurRadius: lifted ? 22 : 14,
                    offset: Offset(0, lifted ? 8 : 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: AppColors.onAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.label,
                    style: AppTypography.label.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Operations digest row ──────────────────────────────────────────

class _DigestRow extends StatelessWidget {
  const _DigestRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$value $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              // Row label is a supporting label (light grey); the count is the
              // metric and reads white when there's work to do.
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent == AppColors.textTertiary
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Decorative affordance → medium grey (a step below the label).
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The desktop "Search or run a command ⌘K" pill — mirrors the shell shortcut
/// so the palette is discoverable, not just known.
class _CommandHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    if (user == null) return const SizedBox.shrink();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showCommandPalette(
          context,
          user: user,
          sections: AppShell.sectionsForRole(user.role),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Search or run a command',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.darkBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⌘K',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sync control ───────────────────────────────────────────────────

/// Relative "last synced" label for the dashboard [_SyncButton]. Pure with an
/// injectable clock so it's unit-testable.
String syncLabel(DateTime? lastSynced, {DateTime? now}) {
  if (lastSynced == null) return 'Sync';
  final d = (now ?? DateTime.now()).difference(lastSynced);
  if (d.inSeconds < 45) return 'Synced just now';
  if (d.inMinutes < 60) return 'Synced ${d.inMinutes}m ago';
  if (d.inHours < 24) return 'Synced ${d.inHours}h ago';
  return 'Synced ${d.inDays}d ago';
}

/// A premium **Sync** control for the dashboard header. Rotates while a refresh
/// is in flight and otherwise shows how long ago the live data was last pulled;
/// tapping force-refreshes the live sources. Desktop shows a labelled pill;
/// mobile shows an icon-only tap target next to the greeting.
class _SyncButton extends StatefulWidget {
  const _SyncButton({
    required this.syncing,
    required this.lastSynced,
    required this.onSync,
    this.compact = false,
  });

  final bool syncing;
  final DateTime? lastSynced;
  final VoidCallback onSync;
  final bool compact;

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _ticker;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.syncing) _spin.repeat();
    // Keep the "3m ago" label honest without leaning on a parent rebuild.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _SyncButton old) {
    super.didUpdateWidget(old);
    if (widget.syncing == old.syncing) return;
    if (widget.syncing) {
      _spin.repeat();
    } else {
      // Let the current turn finish for a smooth stop, then settle to rest.
      _spin
          .animateTo(1, duration: const Duration(milliseconds: 220))
          .whenComplete(() {
            if (mounted) _spin.reset();
          });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.syncing ? 'Syncing…' : syncLabel(widget.lastSynced);
    final onTap = widget.syncing ? null : widget.onSync;
    final icon = RotationTransition(
      turns: _spin,
      child: Icon(
        Icons.sync_rounded,
        size: 15,
        color: widget.syncing ? AppColors.textPrimary : AppColors.textSecondary,
      ),
    );

    if (widget.compact) {
      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Center(child: icon),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? AppColors.textTertiary : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
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

// ─── Branch pulse (desktop rail) ────────────────────────────────────

/// Per-branch open / in-review counts from the live task stream — the
/// executive "where is the load right now" line. Hidden until branch names
/// resolve; facts only, no targets.
class _BranchPulse extends StatelessWidget {
  const _BranchPulse();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final tasks = state.maybeWhen(
          loaded: (t, _, _, _, _) => t,
          orElse: () => const <TaskEntity>[],
        );
        final names = context.read<TaskCubit>().branchNames;
        final byBranch = <String, ({int open, int review})>{};
        for (final t in tasks) {
          final branchId = t.branchId;
          if (branchId == null || branchId.isEmpty) continue;
          final prev = byBranch[branchId] ?? (open: 0, review: 0);
          final isOpen =
              t.status == TaskStatus.pending ||
              t.status == TaskStatus.started ||
              t.status == TaskStatus.rejected;
          final isReview = t.status == TaskStatus.waitingReview;
          if (!isOpen && !isReview) continue;
          byBranch[branchId] = (
            open: prev.open + (isOpen ? 1 : 0),
            review: prev.review + (isReview ? 1 : 0),
          );
        }
        final rows = byBranch.entries.toList()
          ..sort(
            (a, b) => (b.value.open + b.value.review).compareTo(
              a.value.open + a.value.review,
            ),
          );
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSectionHeader(title: 'Branch pulse'),
            GlassContainer(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (final (i, row) in rows.take(4).toList().indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.darkBorder),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              names[row.key] ?? 'Branch',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // Branch name → light grey (secondary info); the
                              // load counts sit a step below at medium grey.
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${row.value.open} open'
                            '${row.value.review > 0 ? ' · ${row.value.review} review' : ''}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Staffing alert ─────────────────────────────────────────────────

/// The highest-priority dashboard signal. A missing manager means a branch has
/// no clear owner for schedules, reviews, or escalations, so this sits above the
/// task queue and links directly to the manager-assignment workflow.
class _StaffingAlert extends StatelessWidget {
  const _StaffingAlert({
    required this.branchesWithoutManagers,
    required this.onTap,
  });

  final int branchesWithoutManagers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = branchesWithoutManagers;
    final title = count == 1
        ? '1 branch needs a manager'
        : '$count branches need a manager';

    Widget message() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(28),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.admin_panel_settings_outlined,
            size: 21,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAFFING GAP',
                style: AppTypography.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: AppTypography.h3),
              const SizedBox(height: 2),
              // Explanatory helper under the white title → medium grey.
              Text(
                'Assign branch ownership so schedules, reviews, and cases have a clear owner.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final action = _InlineAction(label: 'Assign now', onTap: onTap);

    return Semantics(
      button: true,
      label: '$title. Assign now.',
      child: GlassContainer(
        onTap: onTap,
        highlight: true,
        accent: AppColors.warning,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message(),
                  const SizedBox(height: AppSpacing.md),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: message()),
                const SizedBox(width: AppSpacing.lg),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(44, 44),
      ),
      label: Text(label, style: AppTypography.labelSmall),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
    );
  }
}
