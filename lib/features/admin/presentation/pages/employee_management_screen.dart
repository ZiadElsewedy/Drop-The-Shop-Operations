import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:drop/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:drop/features/admin/presentation/employee_metrics.dart';
import 'package:drop/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:drop/features/admin/presentation/widgets/admin_user_sheets.dart';
import 'package:drop/features/admin/presentation/widgets/employee_card.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';

const _kAll = '__all__';
const _kNone = '__none__';

enum _StatusFilter { all, active, inactive }

/// Admin → Employees. List employees, filter by branch, change branch, activate
/// or deactivate, and view details.
class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  String _branchFilter = _kAll;
  _StatusFilter _statusFilter = _StatusFilter.all;
  String _query = '';
  List<BranchEntity> _branches = const [];
  Map<String, String> _branchNames = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersCubit>().load(AdminUserFilter.employees);
      _loadBranches();
      // The admin task stream feeds each card's performance metrics. Load it
      // only if it isn't already streaming (it usually is, from Admin Home).
      final taskCubit = context.read<TaskCubit>();
      final loaded = taskCubit.state
          .maybeWhen(loaded: (_, _, _, _, _) => true, orElse: () => false);
      final user = context.currentUser;
      if (!loaded && user != null) taskCubit.load(user);
    });
  }

  Future<void> _loadBranches() async {
    final branches = await context.read<AdminUsersCubit>().branches();
    if (mounted) {
      setState(() {
        _branches = branches;
        _branchNames = {for (final b in branches) b.id: b.name};
      });
    }
  }

  List<UserEntity> _filter(List<UserEntity> users) {
    Iterable<UserEntity> out = users;
    // Branch.
    switch (_branchFilter) {
      case _kAll:
        break;
      case _kNone:
        out = out.where((u) => u.branchId == null || u.branchId!.isEmpty);
      default:
        out = out.where((u) => u.branchId == _branchFilter);
    }
    // Status.
    switch (_statusFilter) {
      case _StatusFilter.all:
        break;
      case _StatusFilter.active:
        out = out.where((u) => u.isActive);
      case _StatusFilter.inactive:
        out = out.where((u) => !u.isActive);
    }
    // Search.
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      out = out.where((u) =>
          (u.displayName ?? '').toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q));
    }
    return out.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Employees',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: () => context.read<AdminUsersCubit>().refresh(),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.adminCreateAccount),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text('Create account',
            style: AppTypography.label.copyWith(color: AppColors.onAccent)),
      ),
      body: BlocConsumer<AdminUsersCubit, AdminUsersState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          loaded: (users, busy) => _body(users, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _body(List<UserEntity> users, bool busy) {
    final filtered = _filter(users);
    // Per-employee performance, derived from the live admin task stream.
    final tasks = context.watch<TaskCubit>().state.maybeWhen(
        loaded: (t, _, _, _, _) => t, orElse: () => const <TaskEntity>[]);
    final metrics = computeEmployeeMetrics(tasks);
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        _filterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<AdminUsersCubit>().refresh(),
            child: filtered.isEmpty
                ? _empty(users.isEmpty)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                        AppSpacing.sm, AppSpacing.pagePadding, AppSpacing.xxxl),
                    children: [
                      ResponsiveCardGrid(
                        runSpacing: 0, // EmployeeCard carries its own bottom margin
                        ultrawideColumns: 2, // rich cards read best at 2-up max
                        children: [
                          for (var i = 0; i < filtered.length; i++)
                            EntranceFade(
                              delay: staggerDelay(i),
                              child: EmployeeCard(
                                user: filtered[i],
                                metrics: metrics[filtered[i].uid] ??
                                    const EmployeeMetrics(),
                                branchLabel: filtered[i].branchId == null
                                    ? null
                                    : _branchNames[filtered[i].branchId],
                                onTap: () => _showDetails(filtered[i]),
                                actions: _actions(filtered[i]),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.xs),
      child: Column(
        children: [
          AppSearchField(
            hint: 'Search employees',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _branchDropdown()),
              const SizedBox(width: AppSpacing.sm),
              _statusChips(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _branchDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _branchFilter,
          isExpanded: true,
          dropdownColor: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.cardAll,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textTertiary),
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem(value: _kAll, child: Text('All branches')),
            const DropdownMenuItem(value: _kNone, child: Text('No branch')),
            for (final b in _branches)
              DropdownMenuItem(value: b.id, child: Text(b.name)),
          ],
          onChanged: (v) => setState(() => _branchFilter = v ?? _kAll),
        ),
      ),
    );
  }

  Widget _statusChips() {
    Widget chip(_StatusFilter f, IconData icon) {
      final active = _statusFilter == f;
      return GestureDetector(
        onTap: () => setState(() => _statusFilter = f),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color:
                active ? AppColors.primary.withAlpha(28) : AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active ? AppColors.primary : AppColors.darkBorder),
          ),
          child: Icon(icon,
              size: 18,
              color: active ? AppColors.primary : AppColors.textTertiary),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(_StatusFilter.all, Icons.all_inclusive_rounded),
        const SizedBox(width: 6),
        chip(_StatusFilter.active, Icons.check_circle_outline_rounded),
        const SizedBox(width: 6),
        chip(_StatusFilter.inactive, Icons.block_rounded),
      ],
    );
  }

  List<Widget> _actions(UserEntity user) {
    final cubit = context.read<AdminUsersCubit>();
    return [
      AdminActionButton(
        label: 'Details',
        icon: Icons.info_outline_rounded,
        onPressed: () => _showDetails(user),
      ),
      AdminActionButton(
        label: 'Edit Info',
        icon: Icons.edit_outlined,
        onPressed: () =>
            showEditDetailsSheet(context: context, cubit: cubit, user: user),
      ),
      AdminActionButton(
        label: 'Change Branch',
        icon: Icons.store_mall_directory_outlined,
        onPressed: () =>
            showAssignBranchSheet(context: context, cubit: cubit, user: user),
      ),
      AdminActionButton(
        label: 'Position',
        icon: Icons.badge_outlined,
        onPressed: () =>
            showSetPositionSheet(context: context, cubit: cubit, user: user),
      ),
      AdminActionButton(
        label: 'Reset',
        icon: Icons.lock_reset_rounded,
        onPressed: () =>
            showResetAccountSheet(context: context, cubit: cubit, user: user),
      ),
      AdminActionButton(
        label: user.isActive ? 'Deactivate' : 'Activate',
        icon: user.isActive
            ? Icons.block_rounded
            : Icons.check_circle_outline_rounded,
        color: user.isActive ? AppColors.error : AppColors.success,
        onPressed: () => cubit.setActive(user, !user.isActive),
      ),
    ];
  }

  void _showDetails(UserEntity user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(
          (user.displayName != null && user.displayName!.isNotEmpty)
              ? user.displayName!
              : user.email,
          style: AppTypography.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Email', user.email),
            if ((user.phoneNumber ?? '').trim().isNotEmpty)
              _detail('Phone', user.phoneNumber!.trim()),
            if ((user.address ?? '').trim().isNotEmpty)
              _detail('Address', user.address!.trim()),
            if ((user.emergencyContact ?? '').trim().isNotEmpty)
              _detail('Emergency', user.emergencyContact!.trim()),
            _detail('Role', user.role.value),
            if ((user.position ?? '').trim().isNotEmpty)
              _detail('Position', user.position!.trim()),
            _detail(
                'Branch',
                user.branchId == null || user.branchId!.isEmpty
                    ? 'Unassigned'
                    : (_branchNames[user.branchId] ?? user.branchId!)),
            _detail('Status', user.isActive ? 'Active' : 'Inactive'),
            _detail('Employment', user.employmentStatus),
            if (user.mustChangePassword)
              _detail('First login', 'Pending password change'),
            if (!user.isProfileCompleted)
              _detail('Onboarding', 'Profile not completed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: AppTypography.bodySmall,
            children: [
              TextSpan(
                text: '$label: ',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Widget _empty(bool noEmployeesAtAll) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        noEmployeesAtAll
                            ? Icons.groups_outlined
                            : Icons.search_off_rounded,
                        size: 44,
                        color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                        noEmployeesAtAll
                            ? 'No employees yet.'
                            : 'No employees match these filters.',
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
