import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/action_card.dart';
import 'package:drop/core/widgets/admin_section_header.dart';
import 'package:drop/core/widgets/app_shell.dart';
import 'package:drop/core/widgets/command_palette.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/dashboard_metric_card.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/admin/presentation/widgets/pending_actions.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_alert_card.dart'
    show showSwapQueueSheet;
import 'package:drop/features/statistics/domain/entities/statistics_entity.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/live_status_border.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_section.dart';

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
  /// A refresh is in flight — drives the header Sync control's spinner.
  bool _syncing = false;

  /// When the live sources were last (re)pulled — drives "Synced 3m ago".
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Refresh the three live sources that feed the dashboard, tracking a single
  /// [_syncing]/[_lastSynced] pair so the header **Sync** button can show a
  /// spinner and how fresh the numbers are. Awaits all three so pull-to-refresh
  /// and the button both reflect real completion.
  Future<void> _load({bool force = false}) async {
    final user = context.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _syncing = true);
    final startedAt = DateTime.now();
    try {
      await Future.wait([
        context.read<StatisticsCubit>().load(user, forceRefresh: force),
        // The all-branches task stream powers Pending Actions + overdue counts.
        // TaskCubit.load is self-guarding (no-op if already streaming this user
        // unless forced), so a revisit doesn't re-subscribe.
        context.read<TaskCubit>().load(user, forceRefresh: force),
        // Pending swaps stream live (scope = all branches), so the Pending
        // Actions swap count updates the instant a swap settles.
        context.read<ShiftSwapCubit>().loadAll(force: force),
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
    // a scoped builder below, so a task-stream emit no longer rebuilds the whole
    // screen. Desktop gets the executive two-column arrangement; mobile keeps
    // the single column.
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: context.isDesktop ? _desktop(context) : _mobile(context),
    );
  }

  // Stable keys + a fixed per-section stagger so the entrance plays once and
  // never replays when a conditional section appears and shifts the trailing
  // sections' positions.
  Widget _sec(String id, int index, Widget child) => EntranceFade(
    key: ValueKey('admin-sec-$id'),
    delay: staggerDelay(index),
    child: child,
  );

  /// Stats-only greeting section (scope line) — rebuilds on stats, never on
  /// the task stream.
  Widget _greeting() {
    final name = context.currentUser?.displayName;
    return _StatsSection(
      builder: (s) => _Greeting(stats: s, name: name),
    );
  }

  /// Stats + live counts: subscribes to the task stream via a BlocSelector on
  /// the two derived counts, so an emit that doesn't move them rebuilds nothing.
  Widget _operationalSummary() => _DynamicSection(
    builder: (s, overdue, reviews) => Column(
      children: [
        if (s != null && s.branchesWithoutManagers > 0) ...[
          _StaffingAlert(
            branchesWithoutManagers: s.branchesWithoutManagers,
            onTap: () => context.push(RouteNames.adminManagers),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _TaskStatusStrip(
          stats: s,
          overdue: overdue,
          reviews: reviews,
          onTap: () => context.push(
            reviews > 0 && overdue == 0
                ? RouteNames.adminReview
                : RouteNames.adminTasks,
          ),
        ),
      ],
    ),
  );

  /// Always rendered — collapses to a quiet confirmation when empty, so the
  /// queue stays discoverable without competing with real risks.
  Widget _pendingHeader() => _PendingSection(
    builder: (s, overdue, reviews, swaps) {
      final pending = swaps + reviews + overdue;
      return AdminSectionHeader(
        title: 'Pending Actions',
        subtitle: pending > 0 ? '$pending awaiting you' : 'No queued actions',
      );
    },
  );

  Widget _pendingActions() => _PendingSection(
    builder: (s, overdue, reviews, swaps) => PendingActions(
      swaps: swaps,
      reviews: reviews,
      overdue: overdue,
      // Straight to the actionable all-branches queue — the cubit is
      // already streaming loadAll() here. (Pushing the Schedule screen
      // landed on "Pick a branch" and made the admin hunt for the swap.)
      onSwaps: () => showSwapQueueSheet(
        context: context,
        currentUid: context.currentUser?.uid ?? '',
        showBranch: true,
      ),
      onReviews: () => context.push(RouteNames.adminReview),
      onOverdue: () => context.push(RouteNames.adminTasks),
    ),
  );

  Widget _mobile(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        sec(
          'greeting',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _greeting()),
              const SizedBox(width: AppSpacing.sm),
              _syncButton(compact: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        sec('summary', _operationalSummary()),
        const SizedBox(height: AppSpacing.xl),
        sec('pa-header', _pendingHeader()),
        sec('pa', _pendingActions()),
        const SizedBox(height: AppSpacing.xl),
        sec('overview-h', const AdminSectionHeader(title: 'Overview')),
        sec('metrics', _StatsSection(builder: (s) => _metrics(s))),
        const SizedBox(height: AppSpacing.xl),
        sec(
          'feed-h',
          const AdminSectionHeader(
            title: 'Active tasks',
            subtitle: 'Every branch, live',
          ),
        ),
        sec('feed', const TaskFeedSection()),
        const SizedBox(height: AppSpacing.xl),
        sec('qa-h', const AdminSectionHeader(title: 'Quick actions')),
        sec('qa', _quickActions()),
        const SizedBox(height: AppSpacing.xl),
        sec('manage-h', const AdminSectionHeader(title: 'Manage')),
        sec('manage', _manage()),
      ],
    );
  }

  /// Executive desktop arrangement: the operational story (greeting → staffing
  /// risk → task status → metrics → task feed) reads down the wide main column; the
  /// queue-and-launch surfaces (pending actions · quick actions · manage ·
  /// branch pulse) sit in a fixed right rail, always in view.
  Widget _desktop(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        40,
        AppSpacing.lg,
        40,
        AppSpacing.xxxl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sec(
                    'greeting',
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _greeting()),
                        _syncButton(),
                        const SizedBox(width: AppSpacing.sm),
                        _CommandHint(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  sec('summary', _operationalSummary()),
                  const SizedBox(height: AppSpacing.xl),
                  sec(
                    'overview-h',
                    const AdminSectionHeader(title: 'Overview'),
                  ),
                  sec('metrics', _StatsSection(builder: (s) => _metrics(s))),
                  const SizedBox(height: AppSpacing.xl),
                  sec(
                    'feed-h',
                    const AdminSectionHeader(
                      title: 'Active tasks',
                      subtitle: 'Every branch, live — tap to open',
                    ),
                  ),
                  sec('feed', const TaskFeedSection()),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(
              width: 330,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sec('pa-header', _pendingHeader()),
                  sec('pa', _pendingActions()),
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

  // ── Metrics grid ─────────────────────────────────────────────────
  Widget _metrics(StatisticsEntity? s) {
    String v(int? n) => s == null ? '—' : '${n ?? 0}';
    final unstaffed = s?.branchesWithoutManagers ?? 0;
    final reviews = s?.waitingReviews ?? 0;
    return ResponsiveCardGrid(
      tabletColumns: 2,
      desktopColumns: 2,
      ultrawideColumns: 2,
      children: [
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
          icon: Icons.admin_panel_settings_outlined,
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
      ],
    );
  }

  // ── Quick actions ────────────────────────────────────────────────
  Widget _quickActions({bool compact = false}) {
    return _grid(maxItemWidth: compact ? 180 : 300, [
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
  Widget _manage({bool compact = false}) {
    // In the 330px desktop rail a 2-up grid squeezed these horizontal shortcuts
    // until single words broke mid-word ("Employee\ns"). A wide target forces a
    // clean 1-up list there; full-width mobile is already single-column.
    return _grid(maxItemWidth: compact ? 400 : 300, [
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
      ActionCard(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'App & account',
        secondary: true,
        onTap: () => context.push(RouteNames.settings),
      ),
    ]);
  }

  /// Lay [cards] out in a width-aware grid. The
  /// desktop right rail uses a 180px target, which resolves to a stable 2-up
  /// grid at 330px instead of squeezing three unreadable tiles across.
  Widget _grid(List<Widget> cards, {double maxItemWidth = 300}) {
    return ResponsiveCardGrid(maxItemWidth: maxItemWidth, children: cards);
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
/// tapping force-refreshes statistics · the task stream · shift swaps. Desktop
/// shows a labelled pill (mirroring the ⌘K hint); mobile shows an icon-only tap
/// target next to the greeting.
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
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${row.value.open} open'
                            '${row.value.review > 0 ? ' · ${row.value.review} review' : ''}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
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
        final stats = statsState.maybeWhen(
          loaded: (s) => s,
          orElse: () => null,
        );
        // Both counts come from the LIVE task stream (not the TTL-cached stats),
        // so reviewing/finishing a task updates Pending Actions + the summary
        // immediately. The record selector still rebuilds only when one of the
        // two numbers actually moves.
        return BlocSelector<TaskCubit, TaskState, ({int overdue, int reviews})>(
          selector: (state) {
            final tasks = state.maybeWhen(
              loaded: (t, _, _, _, _) => t,
              orElse: () => const <TaskEntity>[],
            );
            return (
              overdue: _overdueCount(tasks),
              reviews: _reviewCount(tasks),
            );
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
    StatisticsEntity? stats,
    int overdue,
    int reviews,
    int swaps,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
      selector: (state) => state.maybeWhen(
        loaded: (swaps, _) => swaps.where((s) => !s.status.isResolved).length,
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
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
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
    final b =
        '${s.totalBranches} ${s.totalBranches == 1 ? 'branch' : 'branches'}';
    final e =
        '${s.totalEmployees} ${s.totalEmployees == 1 ? 'employee' : 'employees'}';
    return '$b · $e';
  }

  @override
  Widget build(BuildContext context) {
    final first = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().split(' ').first
        : 'Admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _date.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('$_salutation, $first', style: AppTypography.h1),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(
              Icons.public_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _scope,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Operational summary ────────────────────────────────────────────

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
              Text(
                'Assign branch ownership so schedules, reviews, and cases have a clear owner.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
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

/// A compact task-health strip. Positive/empty task state stays visible, but it
/// no longer gets hero-card scale or outranks a staffing gap.
class _TaskStatusStrip extends StatelessWidget {
  const _TaskStatusStrip({
    required this.stats,
    required this.overdue,
    required this.reviews,
    required this.onTap,
  });

  final StatisticsEntity? stats;
  final int overdue;
  final int reviews;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loading = stats == null;
    final active = stats?.activeTasks ?? 0;
    final issues = overdue + reviews;
    final hasIssues = issues > 0;
    final accent = loading
        ? AppColors.textSecondary
        : overdue > 0
        ? AppColors.error
        : reviews > 0
        ? AppColors.warning
        : AppColors.success;
    final icon = loading
        ? Icons.sync_rounded
        : overdue > 0
        ? Icons.warning_amber_rounded
        : reviews > 0
        ? Icons.rate_review_rounded
        : Icons.check_circle_rounded;
    final title = loading
        ? 'Checking task status'
        : hasIssues
        ? '$issues task ${issues == 1 ? 'action needs' : 'actions need'} attention'
        : 'Task queue is clear';
    final facts = <String>[
      if (loading) 'Loading live task health',
      if (overdue > 0) '$overdue overdue',
      if (reviews > 0) '$reviews waiting review',
      if (!loading && !hasIssues && active > 0) '$active active',
      if (!loading && !hasIssues) 'No overdue work or reviews waiting',
    ];
    final actionLabel = reviews > 0 && overdue == 0
        ? 'Review now'
        : 'View tasks';

    Widget summary() => Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withAlpha(28),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loading
                    ? 'UPDATING'
                    : hasIssues
                    ? 'TASK QUEUE'
                    : 'ON TRACK',
                style: AppTypography.caption.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(title, style: AppTypography.labelLarge),
              const SizedBox(height: 2),
              Text(
                facts.join(' · '),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final action = _InlineAction(label: actionLabel, onTap: onTap);
    // Living border: an amber orbit while the queue has work needing attention;
    // it flashes (orange when something is overdue) as the count changes, and
    // pulses when overdue. A clear queue shows no orbit. (Radius 20 = the
    // GlassContainer's default AppRadius.card, so the orbit rides its border.)
    return LiveStatusBorder(
      // Orbit colour follows the worst signal: orange when overdue, else amber
      // (in-review) — from the shared per-state palette. No orbit when clear.
      color: hasIssues
          ? (overdue > 0 ? const Color(0xFFFB923C) : kLivingBorderAccent)
          : null,
      pulse: overdue > 0,
      speed: 1.15,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: GlassContainer(
        onTap: onTap,
        highlight: hasIssues,
        accent: accent,
        elevated: hasIssues,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary(),
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: summary()),
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

// ─── Overdue helper ─────────────────────────────────────────────────

/// Count of open tasks (pending/started/rejected) that are past their deadline —
/// the operational "needs attention" signal. Shared by the status strip +
/// Pending Actions.
int _overdueCount(List<TaskEntity> tasks) {
  final now = DateTime.now();
  return tasks.where((t) {
    final d = t.deadline;
    if (d == null) return false;
    final open =
        t.status == TaskStatus.pending ||
        t.status == TaskStatus.started ||
        t.status == TaskStatus.rejected;
    return open && d.isBefore(now);
  }).length;
}

/// Count of tasks awaiting review — derived from the **live** task stream, not
/// the TTL-cached `StatisticsCubit` (which isn't invalidated on a mutation), so
/// the Pending Actions queue + status strip drop the instant a review completes.
int _reviewCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.waitingReview).length;
