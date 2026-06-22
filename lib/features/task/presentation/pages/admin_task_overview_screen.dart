import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/task_status.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/list_skeleton.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/operations/presentation/pages/branch_operations_screen.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/task/presentation/cubit/task_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_empty_state.dart';
import 'package:fbro/features/task/presentation/widgets/task_template_sheets.dart';

/// Admin task home — a **branch-based overview** instead of a single flat list
/// of every task across the company (which doesn't scale past a few branches).
///
/// Each branch is a card with the operational vitals the admin needs to triage
/// at a glance — Active, Pending Review, Overdue, Completion Rate — sorted so
/// the branches that need attention surface first. Tapping a branch drills into
/// that branch's task list (full create / assign / edit / review / delete).
class AdminTaskOverviewScreen extends StatefulWidget {
  const AdminTaskOverviewScreen({super.key});

  @override
  State<AdminTaskOverviewScreen> createState() =>
      _AdminTaskOverviewScreenState();
}

class _AdminTaskOverviewScreenState extends State<AdminTaskOverviewScreen> {
  late Future<List<BranchEntity>> _branchesFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _branchesFuture = Future.value(const []);
  }

  void _load() {
    final user = context.currentUser;
    if (user != null) {
      context.read<TaskCubit>().load(user);
      final future = context.read<TaskCubit>().branches();
      setState(() {
        _branchesFuture = future;
      });
    }
  }

  Future<void> _create() => startNewTaskFlow(
        context: context,
        cubit: context.read<TaskCubit>(),
        isAdmin: true,
        defaultBranchId: '',
      );

  void _manageTemplates() => showManageTemplatesSheet(
        context: context,
        cubit: context.read<TaskCubit>(),
        isAdmin: true,
        defaultBranchId: '',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Task Management', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined,
                color: AppColors.textSecondary),
            tooltip: 'Templates',
            onPressed: _manageTemplates,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Task',
            style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (tasks, busy, directory, _, _) => _overview(tasks, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _overview(List<TaskEntity> tasks, bool busy) {
    return FutureBuilder<List<BranchEntity>>(
      future: _branchesFuture,
      builder: (context, snap) {
        final branches = snap.data ?? const <BranchEntity>[];
        final rows = _buildRows(branches, tasks);
        final company = _BranchMetrics.from(tasks);

        return Column(
          children: [
            if (busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _load(),
                child: rows.isEmpty
                    ? const TaskEmptyState(
                        icon: Icons.store_mall_directory_outlined,
                        message:
                            'No branches yet.\nCreate a branch, then add tasks.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pagePadding,
                          AppSpacing.lg,
                          AppSpacing.pagePadding,
                          AppSpacing.xxxl * 2,
                        ),
                        children: [
                          _CompanySummary(metrics: company, branches: rows.length),
                          const SizedBox(height: AppSpacing.lg),
                          for (var i = 0; i < rows.length; i++)
                            EntranceFade(
                              delay: staggerDelay(i),
                              child: _BranchOverviewCard(
                                row: rows[i],
                                onTap: () => _openBranch(rows[i]),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openBranch(_BranchRow row) {
    // Drill into the operations cockpit (task→operations redesign) — the full
    // per-branch task list is reachable from there via "All tasks".
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BranchOperationsScreen(
        branchId: row.branchId,
        branchName: row.name,
      ),
    ));
  }

  /// Groups tasks by branch and joins them to the branch directory. Branches with
  /// no tasks are still listed (the admin should see every branch); task rows
  /// whose branch is missing from the directory are bucketed as "Unknown branch"
  /// so legacy/orphaned tasks remain visible and actionable. Sorted so branches
  /// needing attention (overdue / pending review) come first.
  List<_BranchRow> _buildRows(
    List<BranchEntity> branches,
    List<TaskEntity> tasks,
  ) {
    final byBranch = <String, List<TaskEntity>>{};
    for (final t in tasks) {
      byBranch.putIfAbsent(t.branchId ?? '', () => []).add(t);
    }

    final rows = <_BranchRow>[
      for (final b in branches)
        _BranchRow(
          branchId: b.id,
          name: b.name,
          location: b.location,
          metrics: _BranchMetrics.from(byBranch[b.id] ?? const []),
        ),
    ];

    // Surface any branch ids that have tasks but no matching branch doc.
    final known = branches.map((b) => b.id).toSet();
    for (final entry in byBranch.entries) {
      if (entry.key.isEmpty || known.contains(entry.key)) continue;
      rows.add(_BranchRow(
        branchId: entry.key,
        name: 'Unknown branch',
        location: null,
        metrics: _BranchMetrics.from(entry.value),
      ));
    }

    rows.sort((a, b) {
      final attn = (b.metrics.needsAttention ? 1 : 0)
          .compareTo(a.metrics.needsAttention ? 1 : 0);
      if (attn != 0) return attn;
      final byOverdue = b.metrics.overdue.compareTo(a.metrics.overdue);
      if (byOverdue != 0) return byOverdue;
      final byReview = b.metrics.pendingReview.compareTo(a.metrics.pendingReview);
      if (byReview != 0) return byReview;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return rows;
  }
}

/// One branch's row in the overview: identity + computed [metrics].
class _BranchRow {
  const _BranchRow({
    required this.branchId,
    required this.name,
    required this.location,
    required this.metrics,
  });
  final String branchId;
  final String name;
  final String? location;
  final _BranchMetrics metrics;
}

/// Operational vitals for a set of tasks (one branch, or the whole company).
class _BranchMetrics {
  const _BranchMetrics({
    required this.total,
    required this.active,
    required this.pendingReview,
    required this.overdue,
    required this.approved,
  });

  /// Open work in progress (pending / started / completed / rejected — i.e. not
  /// yet approved and not currently awaiting review).
  final int active;

  /// Submitted and waiting for a manager/admin decision.
  final int pendingReview;

  /// Past their deadline and not yet done.
  final int overdue;

  /// Approved (closed) tasks.
  final int approved;
  final int total;

  /// Approved ÷ total, or null when the branch has no tasks.
  double? get completionRate => total == 0 ? null : approved / total;

  bool get needsAttention => overdue > 0 || pendingReview > 0;

  factory _BranchMetrics.from(Iterable<TaskEntity> tasks) {
    var total = 0, active = 0, pendingReview = 0, overdue = 0, approved = 0;
    for (final t in tasks) {
      total++;
      switch (t.status) {
        case TaskStatus.waitingReview:
          pendingReview++;
        case TaskStatus.approved:
          approved++;
        case TaskStatus.pending ||
              TaskStatus.started ||
              TaskStatus.completed ||
              TaskStatus.rejected:
          active++;
      }
      if (_overdue(t)) overdue++;
    }
    return _BranchMetrics(
      total: total,
      active: active,
      pendingReview: pendingReview,
      overdue: overdue,
      approved: approved,
    );
  }

  static bool _overdue(TaskEntity t) {
    final d = t.deadline;
    if (d == null) return false;
    final done = t.status == TaskStatus.approved ||
        t.status == TaskStatus.completed ||
        t.status == TaskStatus.waitingReview;
    return !done && d.isBefore(DateTime.now());
  }
}

/// Company-wide snapshot strip at the top of the overview.
class _CompanySummary extends StatelessWidget {
  const _CompanySummary({required this.metrics, required this.branches});
  final _BranchMetrics metrics;
  final int branches;

  @override
  Widget build(BuildContext context) {
    final pct = metrics.completionRate;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          _SummaryStat(value: '$branches', label: 'Branches'),
          _summaryDivider(),
          _SummaryStat(value: '${metrics.active}', label: 'Active'),
          _summaryDivider(),
          _SummaryStat(
            value: '${metrics.pendingReview}',
            label: 'In review',
            emphasised: metrics.pendingReview > 0,
          ),
          _summaryDivider(),
          _SummaryStat(
            value: '${metrics.overdue}',
            label: 'Overdue',
            alert: metrics.overdue > 0,
          ),
          _summaryDivider(),
          _SummaryStat(
            value: pct == null ? '—' : '${(pct * 100).round()}%',
            label: 'Complete',
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(
        width: 1,
        height: 34,
        color: AppColors.darkBorder,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    this.alert = false,
    this.emphasised = false,
  });
  final String value;
  final String label;
  final bool alert;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final color = alert
        ? AppColors.error
        : emphasised
            ? AppColors.textPrimary
            : AppColors.textPrimary;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTypography.h3.copyWith(color: color, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// A single branch card in the admin overview.
class _BranchOverviewCard extends StatelessWidget {
  const _BranchOverviewCard({required this.row, required this.onTap});
  final _BranchRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = row.metrics;
    final pct = m.completionRate;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardAll,
          border: Border.all(
            color: m.needsAttention
                ? AppColors.textTertiary
                : AppColors.darkBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((row.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(row.location!, style: AppTypography.caption),
                      ],
                    ],
                  ),
                ),
                if (m.needsAttention)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _AttentionPill(
                      overdue: m.overdue,
                      pendingReview: m.pendingReview,
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _Metric(value: '${m.active}', label: 'Active'),
                _Metric(value: '${m.pendingReview}', label: 'Pending review'),
                _Metric(
                  value: '${m.overdue}',
                  label: 'Overdue',
                  alert: m.overdue > 0,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  pct == null
                      ? 'No tasks yet'
                      : 'Completion ${(pct * 100).round()}%',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: AppColors.darkSurfaceElevated,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.textPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small "needs attention" pill summarising why (overdue beats review).
class _AttentionPill extends StatelessWidget {
  const _AttentionPill({required this.overdue, required this.pendingReview});
  final int overdue;
  final int pendingReview;

  @override
  Widget build(BuildContext context) {
    final isOverdue = overdue > 0;
    final label = isOverdue
        ? '$overdue overdue'
        : '$pendingReview to review';
    final color = isOverdue ? AppColors.error : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.error_outline_rounded
                : Icons.hourglass_empty_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.alert = false});
  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: 22,
              color: alert ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

