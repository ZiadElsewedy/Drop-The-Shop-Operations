import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/skeleton.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_state.dart';

/// Admin Home (Phase 9 restructure): a focused operations cockpit — only the
/// four headline KPIs (Branches · Employees · Managers · Active Tasks), then
/// clean navigation into each dedicated module. The full metric wall lives on
/// the Analytics page now, so this screen stays uncluttered.
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

  void _load() {
    final user = context.currentUser;
    if (user != null) context.read<StatisticsCubit>().load(user);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          Text('Overview', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.md),
          BlocBuilder<StatisticsCubit, StatisticsState>(
            builder: (context, state) => state.maybeWhen(
              loaded: (s) => _kpis(s),
              error: (_) => _kpis(null),
              orElse: () => const _KpiSkeleton(),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Manage', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.md),
          _navTile(0, Icons.store_mall_directory_outlined, 'Branches',
              'Create and manage branches', RouteNames.adminBranches),
          _navTile(1, Icons.calendar_view_week_outlined, 'Schedules',
              'View and edit any branch schedule', RouteNames.adminSchedule),
          _navTile(2, Icons.supervisor_account_outlined, 'Managers',
              'Assign managers to branches', RouteNames.adminManagers),
          _navTile(3, Icons.groups_outlined, 'Employees',
              'View and manage employees', RouteNames.adminEmployees),
          _navTile(4, Icons.insights_outlined, 'Analytics',
              'Full operational metrics', RouteNames.adminAnalytics),
          _navTile(5, Icons.how_to_reg_outlined, 'Approvals',
              'Approve or reject new sign-ups', RouteNames.adminApprovals),
          _navTile(6, Icons.settings_outlined, 'Settings',
              'Account and app settings', RouteNames.settings),
        ],
      ),
    );
  }

  Widget _kpis(StatisticsEntity? s) {
    final cards = [
      _Kpi('Branches', s == null ? '—' : '${s.totalBranches}',
          Icons.store_mall_directory_outlined, RouteNames.adminBranches),
      _Kpi('Employees', s == null ? '—' : '${s.totalEmployees}',
          Icons.groups_outlined, RouteNames.adminEmployees),
      _Kpi('Managers', s == null ? '—' : '${s.totalManagers}',
          Icons.supervisor_account_outlined, RouteNames.adminManagers),
      _Kpi('Active tasks', s == null ? '—' : '${s.activeTasks}',
          Icons.assignment_outlined, RouteNames.adminTasks),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: w,
                child: EntranceFade(
                  delay: staggerDelay(i),
                  child: _KpiCard(
                    kpi: cards[i],
                    onTap: () => context.push(cards[i].route),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _navTile(
      int index, IconData icon, String title, String subtitle, String route) {
    return EntranceFade(
      delay: staggerDelay(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(title, style: AppTypography.label),
          subtitle: Text(subtitle, style: AppTypography.caption),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
          onTap: () => context.push(route),
        ),
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.icon, this.route);
  final String label;
  final String value;
  final IconData icon;
  final String route;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, required this.onTap});
  final _Kpi kpi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.cardAll,
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(kpi.icon, size: 22, color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(kpi.value, style: AppTypography.h1, maxLines: 1),
            const SizedBox(height: 2),
            Text(kpi.label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: AppRadius.cardAll,
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(
                          width: 22,
                          height: 22,
                          borderRadius:
                              BorderRadius.all(Radius.circular(6))),
                      SizedBox(height: AppSpacing.lg),
                      Skeleton(width: 54, height: 28),
                      SizedBox(height: 6),
                      Skeleton(width: 70, height: 11),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
