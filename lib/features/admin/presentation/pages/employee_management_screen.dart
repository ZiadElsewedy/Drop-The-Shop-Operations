import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_sheets.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';

const _kAll = '__all__';
const _kNone = '__none__';

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
  List<BranchEntity> _branches = const [];
  Map<String, String> _branchNames = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersCubit>().load(AdminUserFilter.employees);
      _loadBranches();
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
    switch (_branchFilter) {
      case _kAll:
        return users;
      case _kNone:
        return users
            .where((u) => u.branchId == null || u.branchId!.isEmpty)
            .toList();
      default:
        return users.where((u) => u.branchId == _branchFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Employees', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => context.read<AdminUsersCubit>().refresh(),
          ),
        ],
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
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        _filterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<AdminUsersCubit>().refresh(),
            child: filtered.isEmpty
                ? _empty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                        AppSpacing.sm, AppSpacing.pagePadding, AppSpacing.xxxl),
                    children: [
                      for (final u in filtered)
                        AdminUserCard(
                          user: u,
                          branchLabel: u.branchId == null
                              ? null
                              : _branchNames[u.branchId],
                          actions: _actions(u),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
      ),
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
        label: 'Change Branch',
        icon: Icons.store_mall_directory_outlined,
        onPressed: () =>
            showAssignBranchSheet(context: context, cubit: cubit, user: user),
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
            _detail('Role', user.role.value),
            _detail(
                'Branch',
                user.branchId == null || user.branchId!.isEmpty
                    ? 'Unassigned'
                    : (_branchNames[user.branchId] ?? user.branchId!)),
            _detail('Status', user.isActive ? 'Active' : 'Inactive'),
            _detail('Approval', user.approvalStatus.value),
            _detail('Sign-in', user.authProvider),
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

  Widget _empty() => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Text('No employees match this filter.',
                    style: AppTypography.bodySmall, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      );
}
