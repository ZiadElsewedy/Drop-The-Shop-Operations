import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/action_card.dart';
import 'package:fbro/core/widgets/admin_section_header.dart';
import 'package:fbro/core/widgets/animated_count.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/dashboard_metric_card.dart';
import 'package:fbro/core/widgets/brand_watermark.dart';
import 'package:fbro/core/widgets/glass_container.dart';
import 'package:fbro/features/admin/presentation/widgets/pending_actions.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/cubit/task_state.dart';

/// Admin Home — an operations **command center**. Pulls from live sources
/// (statistics · the task stream · shift swaps) so an admin instantly sees
/// branch health, workforce, tasks waiting review, overdue work and operational
/// issues, then reaches any critical action in one tap.
///
/// Composition over a monolith: every visual is a shared component
/// (`GlassContainer`, `DashboardMetricCard`, `ActionCard`, `AdminSectionHeader`,
/// `TimelineTile`) — this screen only arranges them and derives the data.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final user = context.currentUser;
    if (user == null) return;
    context.read<StatisticsCubit>().load(user, forceRefresh: force);
    // The all-branches task stream powers the Pending Actions + overdue counts.
    // TaskCubit.load is now self-guarding (no-op if already streaming this user
    // unless forced), so a revisit doesn't re-subscribe.
    context.read<TaskCubit>().load(user, forceRefresh: force);
    // Pending swaps now stream live (scope = all branches), so the Pending
    // Actions swap count updates the instant a swap settles — no refresh.
    context.read<ShiftSwapCubit>().loadAll(force: force);
  }

  @override
  Widget build(BuildContext context) {
    // No top-level cubit subscription: the ListView scaffold + static sections
    // build once. Each data-driven section subscribes to only what it needs via
    // a scoped builder below, so a task-stream emit no longer rebuilds the whole
    // screen. `_pending` is local (setState on load); swaps stream live.
    final name = context.currentUser?.displayName;

    // Stable keys + a fixed per-section stagger so the entrance plays once and
    // never replays when the conditional "Pending approvals" section appears and
    // shifts the trailing sections' positions.
    var i = 0;
    Widget sec(String id, Widget child) => EntranceFade(
          key: ValueKey('admin-sec-$id'),
          delay: staggerDelay(i++),
          child: child,
        );

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
            AppSpacing.pagePadding, AppSpacing.xxxl),
        children: [
          // Stats-only (scope line) — rebuilds on stats, never on the task stream.
          sec('greeting',
              _StatsSection(builder: (s) => _Greeting(stats: s, name: name))),
          const SizedBox(height: AppSpacing.xl),
          // Stats + overdue: subscribes to the task stream via a BlocSelector on
          // the overdue *count*, so an emit that doesn't move it rebuilds nothing.
          sec(
              'hero',
              _DynamicSection(
                  builder: (s, overdue, reviews) =>
                      _Hero(stats: s, overdue: overdue, reviews: reviews))),
          const SizedBox(height: AppSpacing.xl),
          // Always rendered — shows an all-clear state when empty, so the panel
          // never silently disappears.
          sec('pa-header', _PendingSection(builder: (s, overdue, reviews, swaps) {
            final pending = swaps + reviews + overdue;
            return AdminSectionHeader(
              title: 'Pending Actions',
              subtitle:
                  pending > 0 ? '$pending awaiting you' : "You're all caught up",
            );
          })),
          sec(
              'pa',
              _PendingSection(
                  builder: (s, overdue, reviews, swaps) => PendingActions(
                        swaps: swaps,
                        reviews: reviews,
                        overdue: overdue,
                        onSwaps: () => context.push(RouteNames.adminSchedule),
                        onReviews: () => context.push(RouteNames.adminReview),
                        onOverdue: () => context.push(RouteNames.adminTasks),
                      ))),
          const SizedBox(height: AppSpacing.xl),
          sec('overview-h', const AdminSectionHeader(title: 'Overview')),
          // Stats-only (the metric grid has no task dependency).
          sec('metrics', _StatsSection(builder: (s) => _metrics(s))),
          const SizedBox(height: AppSpacing.xl),
          sec('qa-h', const AdminSectionHeader(title: 'Quick actions')),
          sec('qa', _quickActions()),
          const SizedBox(height: AppSpacing.xl),
          sec('manage-h', const AdminSectionHeader(title: 'Manage')),
          sec('manage', _manage()),
        ],
      ),
    );
  }

  // ── Metrics grid ─────────────────────────────────────────────────
  Widget _metrics(StatisticsEntity? s) {
    String v(int? n) => s == null ? '—' : '${n ?? 0}';
    final unstaffed = s?.branchesWithoutManagers ?? 0;
    final reviews = s?.waitingReviews ?? 0;
    return _grid([
      DashboardMetricCard(
        icon: Icons.store_mall_directory_outlined,
        value: v(s?.totalBranches),
        label: 'Branches',
        trend: s == null
            ? null
            : (unstaffed > 0 ? '$unstaffed without manager' : 'All staffed'),
        trendColor: unstaffed > 0 ? AppColors.warning : AppColors.success,
        onTap: () => context.push(RouteNames.adminBranches),
      ),
      DashboardMetricCard(
        icon: Icons.groups_outlined,
        value: v(s?.totalEmployees),
        label: 'Employees',
        trend: s == null ? null : '${s.totalManagers} managers',
        onTap: () => context.push(RouteNames.adminEmployees),
      ),
      DashboardMetricCard(
        icon: Icons.supervisor_account_outlined,
        value: v(s?.totalManagers),
        label: 'Managers',
        onTap: () => context.push(RouteNames.adminManagers),
      ),
      DashboardMetricCard(
        icon: Icons.fact_check_outlined,
        value: v(s?.activeTasks),
        label: 'Active tasks',
        trend: s == null
            ? null
            : (reviews > 0 ? '$reviews in review' : 'None in review'),
        trendColor: reviews > 0 ? AppColors.warning : AppColors.textSecondary,
        onTap: () => context.push(RouteNames.adminTasks),
      ),
    ]);
  }

  // ── Quick actions ────────────────────────────────────────────────
  Widget _quickActions() {
    return _grid([
      ActionCard(
        icon: Icons.add_business_outlined,
        title: 'Add Branch',
        onTap: () => context.push(RouteNames.adminBranches),
      ),
      ActionCard(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Create Account',
        onTap: () => context.push(RouteNames.adminCreateAccount),
      ),
      ActionCard(
        icon: Icons.assignment_add,
        title: 'Assign Task',
        onTap: () => context.push(RouteNames.adminTasks),
      ),
      ActionCard(
        icon: Icons.supervisor_account_outlined,
        title: 'Add Manager',
        onTap: () => context.push(RouteNames.adminManagers),
      ),
    ]);
  }

  // ── Manage (module directory) ────────────────────────────────────
  Widget _manage() {
    return _grid([
      ActionCard(
        icon: Icons.calendar_view_week_outlined,
        title: 'Schedules',
        subtitle: 'Any branch',
        onTap: () => context.push(RouteNames.adminSchedule),
      ),
      ActionCard(
        icon: Icons.groups_outlined,
        title: 'Employees',
        subtitle: 'Manage staff',
        onTap: () => context.push(RouteNames.adminEmployees),
      ),
      ActionCard(
        icon: Icons.insights_outlined,
        title: 'Analytics',
        subtitle: 'Full metrics',
        onTap: () => context.push(RouteNames.adminAnalytics),
      ),
      ActionCard(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'App & account',
        onTap: () => context.push(RouteNames.settings),
      ),
    ]);
  }

  /// Lay out [cards] two-per-row at equal height.
  Widget _grid(List<Widget> cards) {
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
                bottom: i + 2 < cards.length ? AppSpacing.md : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child:
                        i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Scoped rebuild helpers (P1) ────────────────────────────────────

/// Rebuilds [builder] only when the dashboard **statistics** change — never on
/// the task stream. Used for stats-only sections (greeting scope, metric grid).
class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.builder});
  final Widget Function(StatisticsEntity? stats) builder;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<StatisticsCubit, StatisticsState>(
        builder: (context, state) =>
            builder(state.maybeWhen(loaded: (s) => s, orElse: () => null)),
      );
}

/// Rebuilds [builder] on a statistics change, and on the task stream **only when
/// the overdue count changes** — a `BlocSelector` over the derived `int`, not the
/// whole task list, so a task emit that doesn't move the number rebuilds nothing.
class _DynamicSection extends StatelessWidget {
  const _DynamicSection({required this.builder});
  final Widget Function(StatisticsEntity? stats, int overdue, int reviews)
      builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final stats =
            statsState.maybeWhen(loaded: (s) => s, orElse: () => null);
        // Both counts come from the LIVE task stream (not the TTL-cached stats),
        // so reviewing/finishing a task updates Pending Actions + the hero
        // immediately. The record selector still rebuilds only when one of the
        // two numbers actually moves.
        return BlocSelector<TaskCubit, TaskState, ({int overdue, int reviews})>(
          selector: (state) {
            final tasks = state.maybeWhen(
                loaded: (t, _, _, _, _) => t,
                orElse: () => const <TaskEntity>[]);
            return (overdue: _overdueCount(tasks), reviews: _reviewCount(tasks));
          },
          builder: (context, c) => builder(stats, c.overdue, c.reviews),
        );
      },
    );
  }
}

/// Like [_DynamicSection] but also threads the **live unresolved swap count**
/// from `ShiftSwapCubit` (scope = all branches) — so Pending Actions' swap row
/// updates the instant a swap is approved/rejected, with no refresh. Rebuilds
/// only when the swap count, overdue or review numbers actually move.
class _PendingSection extends StatelessWidget {
  const _PendingSection({required this.builder});
  final Widget Function(
      StatisticsEntity? stats, int overdue, int reviews, int swaps) builder;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
      selector: (state) => state.maybeWhen(
        loaded: (swaps, _) =>
            swaps.where((s) => !s.status.isResolved).length,
        orElse: () => 0,
      ),
      builder: (context, swaps) => _DynamicSection(
        builder: (stats, overdue, reviews) =>
            builder(stats, overdue, reviews, swaps),
      ),
    );
  }
}

// ─── Greeting header ────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.stats, this.name});
  final StatisticsEntity? stats;
  final String? name;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _date {
    final n = DateTime.now();
    return '${_weekdays[n.weekday - 1]}, ${n.day} ${_months[n.month - 1]}';
  }

  String get _scope {
    final s = stats;
    if (s == null) return 'Operations overview';
    final b = '${s.totalBranches} ${s.totalBranches == 1 ? 'branch' : 'branches'}';
    final e =
        '${s.totalEmployees} ${s.totalEmployees == 1 ? 'employee' : 'employees'}';
    return '$b · $e';
  }

  @override
  Widget build(BuildContext context) {
    final first =
        (name != null && name!.trim().isNotEmpty) ? name!.trim().split(' ').first : 'Admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_date.toUpperCase(),
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.textTertiary, letterSpacing: 1.0)),
        const SizedBox(height: AppSpacing.xs),
        Text('$_salutation, $first', style: AppTypography.h1),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(Icons.public_rounded,
                size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(_scope, style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}

// ─── Hero card ──────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.stats, required this.overdue, required this.reviews});
  final StatisticsEntity? stats;
  final int overdue;

  /// Live count of tasks awaiting review (from the task stream, not stats).
  final int reviews;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final active = s?.activeTasks ?? 0;
    final doneToday = s?.completedTasksToday ?? 0;
    final totalToday = doneToday + active;
    final progress = totalToday == 0 ? 0.0 : doneToday / totalToday;

    final String title, value, summary, cta, route;
    final Color accent;
    final bool highlight;
    final IconData icon;

    if (reviews > 0) {
      title = 'Tasks awaiting review';
      value = '$reviews';
      summary =
          '$reviews ${reviews == 1 ? 'task' : 'tasks'} submitted and waiting for your review.';
      cta = 'Review tasks';
      route = RouteNames.adminReview;
      accent = AppColors.warning;
      highlight = true;
      icon = Icons.rate_review_rounded;
    } else if (overdue > 0) {
      title = 'Overdue tasks';
      value = '$overdue';
      summary =
          '$overdue ${overdue == 1 ? 'task is' : 'tasks are'} past the deadline and not yet submitted.';
      cta = 'View tasks';
      route = RouteNames.adminTasks;
      accent = AppColors.error;
      highlight = true;
      icon = Icons.warning_amber_rounded;
    } else {
      title = 'All clear';
      value = '$active';
      summary =
          'No reviews or overdue tasks waiting. $active active ${active == 1 ? 'task' : 'tasks'} in progress.';
      cta = 'View tasks';
      route = RouteNames.adminTasks;
      accent = AppColors.success;
      highlight = false;
      icon = Icons.check_circle_rounded;
    }

    return GlassContainer(
      highlight: highlight,
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: BrandWatermark(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  highlight ? 'NEEDS ATTENTION' : 'ALL CLEAR',
                  style: AppTypography.caption.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Text(
                '$doneToday/$totalToday today',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Big metric beside its title + summary — one tight block, no dead space.
          Row(
            children: [
              AnimatedCount(
                  value: int.tryParse(value) ?? 0,
                  style: AppTypography.displayMedium),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.h3),
                    const SizedBox(height: 2),
                    Text(summary,
                        style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: cta,
            icon: const Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppColors.textDark),
            onPressed: () => context.push(route),
          ),
        ],
        ),
      ),
    );
  }
}

// ─── Overdue helper ─────────────────────────────────────────────────

/// Count of open tasks (pending/started/rejected) that are past their deadline —
/// the operational "needs attention" signal. Shared by the hero + Pending Actions.
int _overdueCount(List<TaskEntity> tasks) {
  final now = DateTime.now();
  return tasks.where((t) {
    final d = t.deadline;
    if (d == null) return false;
    final open = t.status == TaskStatus.pending ||
        t.status == TaskStatus.started ||
        t.status == TaskStatus.rejected;
    return open && d.isBefore(now);
  }).length;
}

/// Count of tasks awaiting review — derived from the **live** task stream, not
/// the TTL-cached `StatisticsCubit` (which isn't invalidated on a mutation), so
/// the Pending Actions queue + hero drop the instant a review completes.
int _reviewCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.waitingReview).length;

