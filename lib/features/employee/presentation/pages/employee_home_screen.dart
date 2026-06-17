import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_motion.dart';
import 'package:fbro/core/widgets/skeleton.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:fbro/features/statistics/presentation/widgets/dashboard_section.dart';
import 'package:fbro/features/statistics/presentation/widgets/stat_grid.dart';

/// Employee dashboard (Phase 6, +Phase 10 focus): today's shift up top, then the
/// employee's own task counts. Minimal, daily-action focused.
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
    final user = context.currentUser;
    if (user != null) context.read<StatisticsCubit>().load(user);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthCubit, UserEntity?>(
      (c) => c.state.maybeWhen(authenticated: (u) => u, orElse: () => null),
    );
    final greeting = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? 'Hello, ${user.displayName}'
        : 'Hello';

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
              loaded: (s) => _content(context, s),
              error: (m) => _errorCard(m),
              orElse: () => _loadingSkeleton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, StatisticsEntity s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntranceFade(child: _shiftCard(s.currentShiftName, s.upcomingShiftName)),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Your tasks'),
        EntranceFade(
          delay: staggerDelay(1),
          child: StatGrid(items: [
            StatItem('Assigned', '${s.assignedTasks}',
                Icons.assignment_outlined),
            StatItem('Pending', '${s.pendingTasks}',
                Icons.pending_actions_outlined),
            StatItem('Waiting review', '${s.waitingReviews}',
                Icons.rate_review_outlined),
            StatItem('Completed', '${s.completedTasks}',
                Icons.task_alt_outlined),
          ]),
        ),
      ],
    );
  }

  Widget _shiftCard(String? shiftName, String? upcoming) {
    final off = shiftName == null || shiftName.isEmpty;
    final label = off
        ? 'Off today'
        : '${shiftName[0].toUpperCase()}${shiftName.substring(1)} shift';
    final icon = off
        ? Icons.weekend_outlined
        : (shiftName == 'morning'
            ? Icons.wb_sunny_outlined
            : Icons.nightlight_outlined);
    return Container(
      width: double.infinity,
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today’s shift', style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(label, style: AppTypography.h3),
                if (upcoming != null && upcoming.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Text('Next: $upcoming', style: AppTypography.bodySmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingSkeleton() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 80, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: AppSpacing.xl),
        SectionHeader('Your tasks'),
        StatGridSkeleton(count: 4),
      ],
    );
  }

  Widget _errorCard(String message) {
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
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
