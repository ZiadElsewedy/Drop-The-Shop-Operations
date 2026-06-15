import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:fbro/features/statistics/presentation/widgets/stat_grid.dart';

/// Employee dashboard (Phase 6): current shift + the employee's own task stats.
class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
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
    final user = context.select<AuthCubit, UserEntity?>(
      (c) => c.state.maybeWhen(authenticated: (u) => u, orElse: () => null),
    );
    final greeting = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? 'Hello, ${user.displayName}!'
        : 'Hello!';

    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          Text(greeting, style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text('Here is your day', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          BlocBuilder<StatisticsCubit, StatisticsState>(
            builder: (context, state) => state.maybeWhen(
              loaded: (s) => _content(s),
              error: (m) => _message(m),
              orElse: () => _message(null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(StatisticsEntity s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shiftCard(s.currentShiftName),
        const SizedBox(height: AppSpacing.lg),
        StatGrid(items: [
          StatItem('Assigned', '${s.assignedTasks}', Icons.assignment_outlined),
          StatItem('Pending', '${s.pendingTasks}', Icons.pending_actions_outlined),
          StatItem('Waiting review', '${s.waitingReviews}',
              Icons.rate_review_outlined),
          StatItem('Completed', '${s.completedTasks}', Icons.task_alt_outlined),
        ]),
      ],
    );
  }

  Widget _shiftCard(String? shiftName) {
    final label = (shiftName == null || shiftName.isEmpty)
        ? 'No shift assigned'
        : '${shiftName[0].toUpperCase()}${shiftName.substring(1)} shift';
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
          const Icon(Icons.schedule_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current shift', style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(label, style: AppTypography.label),
            ],
          ),
        ],
      ),
    );
  }

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
              Text('Loading…', style: AppTypography.body),
            ])
          : Text(error,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
    );
  }
}
