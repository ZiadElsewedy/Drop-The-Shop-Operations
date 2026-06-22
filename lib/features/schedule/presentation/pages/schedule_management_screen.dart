import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:fbro/features/schedule/presentation/widgets/manager_schedule_view.dart';

/// Admin schedule screen (Phase 7 redesign) — a single operations-control
/// surface: the weekly coverage heatmap for **any** branch (branch selector),
/// with swap requests across all branches surfaced as a floating alert inside
/// the grid (no separate tab). The grid refreshes itself when a swap settles.
class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    // Branches resolve the swap cards' labels; every branch's swaps form the
    // admin's global approval queue.
    context.read<BranchCubit>().load();
    context.read<ShiftSwapCubit>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Branch Schedules', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<ScheduleCubit>().refresh();
              context.read<ShiftSwapCubit>().refresh();
            },
          ),
        ],
      ),
      body: const ManagerScheduleView(isAdmin: true),
    );
  }
}
