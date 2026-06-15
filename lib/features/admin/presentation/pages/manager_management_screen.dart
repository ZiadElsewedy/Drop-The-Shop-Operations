import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_sheets.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_users_list_view.dart';

/// Admin → Managers. List managers, assign/change their branch, activate or
/// deactivate, demote to employee, and add a manager (promote an employee).
class ManagerManagementScreen extends StatelessWidget {
  const ManagerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminUsersListView(
      title: 'Managers',
      filter: AdminUserFilter.managers,
      emptyMessage: 'No managers yet.\nTap "Add Manager" to promote an employee.',
      onAdd: () => showPromoteManagerSheet(
        context: context,
        cubit: context.read<AdminUsersCubit>(),
      ),
      addLabel: 'Add Manager',
      actionsBuilder: (context, user) {
        final cubit = context.read<AdminUsersCubit>();
        return [
          AdminActionButton(
            label: 'Assign Branch',
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
          AdminActionButton(
            label: 'Demote',
            icon: Icons.arrow_downward_rounded,
            color: AppColors.warning,
            onPressed: () => cubit.changeRole(user, UserRole.employee),
          ),
        ];
      },
    );
  }
}
