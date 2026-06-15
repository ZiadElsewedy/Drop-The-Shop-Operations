import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/admin/domain/entities/admin_stats.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_stats_cubit.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_stats_state.dart';

/// Admin dashboard (Phase 5): a reports overview (aggregated counts) plus
/// navigation into the management modules. Hosted inside `AdminShell`.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<AdminStatsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<AdminStatsCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          Text('Overview', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          BlocBuilder<AdminStatsCubit, AdminStatsState>(
            builder: (context, state) => state.maybeWhen(
              loaded: (stats) => _stats(stats),
              error: (m) => _statsMessage(m),
              orElse: () => _statsMessage(null),
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

  Widget _stats(AdminStats s) {
    final items = [
      ('Branches', s.totalBranches, Icons.store_mall_directory_outlined),
      ('Managers', s.totalManagers, Icons.supervisor_account_outlined),
      ('Employees', s.totalEmployees, Icons.groups_outlined),
      ('Pending', s.pendingApprovals, Icons.how_to_reg_outlined),
      ('Active tasks', s.activeTasks, Icons.assignment_outlined),
      ('Completed', s.completedTasks, Icons.task_alt_outlined),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, icon) in items)
              SizedBox(width: w, child: _statCard(label, value, icon)),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text('$value', style: AppTypography.h2),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _statsMessage(String? error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          if (error == null) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Loading stats…', style: AppTypography.body),
          ] else
            Expanded(
              child: Text(error,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.error)),
            ),
        ],
      ),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
