import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:fbro/features/statistics/presentation/widgets/stat_grid.dart';

/// Admin dashboard (Phase 5 nav + Phase 6 live stats): a global operational
/// overview plus navigation into the management modules. Hosted in `AdminShell`.
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
    final user = context.read<AuthCubit>().state.maybeWhen(
          authenticated: (u) => u,
          orElse: () => null,
        );
    if (user != null) context.read<StatisticsCubit>().load(user);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          Text('Store overview', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          BlocBuilder<StatisticsCubit, StatisticsState>(
            builder: (context, state) => state.maybeWhen(
              loaded: (s) => StatGrid(items: _items(s)),
              error: (m) => _message(m),
              orElse: () => _message(null),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Manage', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          _navTile(Icons.store_mall_directory_outlined, 'Branches',
              'Create and manage branches', RouteNames.adminBranches),
          _navTile(Icons.supervisor_account_outlined, 'Managers',
              'Assign managers to branches', RouteNames.adminManagers),
          _navTile(Icons.groups_outlined, 'Employees',
              'View and manage employees', RouteNames.adminEmployees),
          _navTile(Icons.how_to_reg_outlined, 'Pending Approvals',
              'Approve or reject new sign-ups', RouteNames.adminApprovals),
        ],
      ),
    );
  }

  List<StatItem> _items(StatisticsEntity s) => [
        StatItem('Branches', '${s.totalBranches}',
            Icons.store_mall_directory_outlined),
        StatItem('Managers', '${s.totalManagers}',
            Icons.supervisor_account_outlined),
        StatItem('Employees', '${s.totalEmployees}', Icons.groups_outlined),
        StatItem('Pending approvals', '${s.pendingApprovals}',
            Icons.how_to_reg_outlined),
        StatItem('Active tasks', '${s.activeTasks}', Icons.assignment_outlined),
        StatItem('Completed tasks', '${s.completedTasks}',
            Icons.task_alt_outlined),
        StatItem('Waiting reviews', '${s.waitingReviews}',
            Icons.rate_review_outlined),
        StatItem('Rejected today', '${s.rejectedTasksToday}',
            Icons.cancel_outlined),
        StatItem('No-manager branches', '${s.branchesWithoutManagers}',
            Icons.report_gmailerrorred_outlined),
      ];

  Widget _message(String? error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: error == null
          ? Row(children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: AppSpacing.md),
              Text('Loading stats…', style: AppTypography.body),
            ])
          : Text(error,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.error)),
    );
  }

  Widget _navTile(IconData icon, String title, String subtitle, String route) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTypography.label),
        subtitle: Text(subtitle, style: AppTypography.caption),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textTertiary),
        onTap: () => context.push(route),
      ),
    );
  }
}
