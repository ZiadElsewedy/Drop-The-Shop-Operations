import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:fbro/features/schedule/presentation/widgets/manager_schedule_view.dart';
import 'package:fbro/features/schedule/presentation/widgets/swap_view.dart';

/// Manager schedule screen (Phase 7). Two tabs: the weekly-schedule editor for
/// the manager's own branch, and the branch's shift-swap approval queue.
class BranchScheduleScreen extends StatefulWidget {
  const BranchScheduleScreen({super.key});

  @override
  State<BranchScheduleScreen> createState() => _BranchScheduleScreenState();
}

class _BranchScheduleScreenState extends State<BranchScheduleScreen> {
  String _uid = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user == null) return;
    _uid = user.uid;
    context.read<ShiftSwapCubit>().loadBranch(user.branchId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          title: Text('Schedule', style: AppTypography.h3),
          bottom: const TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Schedule'),
              Tab(text: 'Swap Requests'),
            ],
          ),
        ),
        // A manager-approved swap rewrites the roster — refresh the Schedule tab
        // the moment a swap action settles, so the manager never has to pull to
        // refresh to see the change. Fires only after a mutation (busy → idle),
        // not on first load.
        body: BlocListener<ShiftSwapCubit, ShiftSwapState>(
          listenWhen: (prev, curr) =>
              prev.maybeWhen(loaded: (_, busy) => busy, orElse: () => false) &&
              curr.maybeWhen(loaded: (_, busy) => !busy, orElse: () => false),
          listener: (context, _) => context.read<ScheduleCubit>().refresh(),
          child: TabBarView(
            children: [
              const ManagerScheduleView(isAdmin: false),
              SwapListView(isManager: true, currentUid: _uid),
            ],
          ),
        ),
      ),
    );
  }
}
