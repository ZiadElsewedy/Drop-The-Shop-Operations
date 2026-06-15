import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:fbro/features/statistics/presentation/widgets/stat_grid.dart';

/// Manager dashboard (Phase 6): live operational stats for the manager's own
/// branch. Shifts/tasks management lives behind the role-chrome icons.
class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
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
          Text('Branch overview', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          BlocBuilder<StatisticsCubit, StatisticsState>(
            builder: (context, state) => state.maybeWhen(
              loaded: (s) => StatGrid(items: _items(s)),
              error: (m) => _message(m),
              orElse: () => _message(null),
            ),
          ),
        ],
      ),
    );
  }

  List<StatItem> _items(StatisticsEntity s) => [
        StatItem('Employees', '${s.employeesInBranch}', Icons.groups_outlined),
        StatItem('Active tasks', '${s.activeTasks}', Icons.assignment_outlined),
        StatItem('Waiting reviews', '${s.waitingReviews}',
            Icons.rate_review_outlined),
        StatItem('Completed today', '${s.completedTasksToday}',
            Icons.task_alt_outlined),
        StatItem('Morning shift', '${s.morningShiftEmployees}',
            Icons.wb_sunny_outlined),
        StatItem('Night shift', '${s.nightShiftEmployees}',
            Icons.nightlight_outlined),
        StatItem('Rejected tasks', '${s.rejectedTasks}', Icons.cancel_outlined),
        StatItem('Daily tasks', '${s.dailyTasks}', Icons.event_repeat_outlined),
        StatItem('Special tasks', '${s.specialTasks}', Icons.star_outline_rounded),
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
              style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
    );
  }
}
