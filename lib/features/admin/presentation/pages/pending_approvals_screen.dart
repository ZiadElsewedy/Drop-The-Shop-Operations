import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_sheets.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_users_list_view.dart';

/// Admin → Pending Approvals. Review newly-registered users and approve (assign
/// role + branch, activate) or reject them.
class PendingApprovalsScreen extends StatelessWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminUsersListView(
      title: 'Pending Approvals',
      filter: AdminUserFilter.pending,
      emptyMessage: 'No pending users. 🎉\nNew sign-ups will appear here.',
      actionsBuilder: (context, user) {
        final cubit = context.read<AdminUsersCubit>();
        return [
          AdminActionButton(
            label: 'Approve',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            onPressed: () =>
                showApproveSheet(context: context, cubit: cubit, user: user),
          ),
          AdminActionButton(
            label: 'Reject',
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            onPressed: () => cubit.reject(user),
          ),
        ];
      },
    );
  }
}
