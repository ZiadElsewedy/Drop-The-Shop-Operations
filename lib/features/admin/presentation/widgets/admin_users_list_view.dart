import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:fbro/features/admin/presentation/widgets/admin_user_card.dart';

typedef AdminUserActions = List<Widget> Function(
    BuildContext context, UserEntity user);

/// Reusable scaffolded list for an admin user slice (managers / pending).
/// Loads the [filter] on init, resolves branch names for display, and renders
/// each user via [AdminUserCard] with screen-supplied [actionsBuilder].
class AdminUsersListView extends StatefulWidget {
  const AdminUsersListView({
    super.key,
    required this.title,
    required this.filter,
    required this.emptyMessage,
    required this.actionsBuilder,
    this.onAdd,
    this.addLabel,
  });

  final String title;
  final AdminUserFilter filter;
  final String emptyMessage;
  final AdminUserActions actionsBuilder;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  State<AdminUsersListView> createState() => _AdminUsersListViewState();
}

class _AdminUsersListViewState extends State<AdminUsersListView> {
  Map<String, String> _branchNames = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersCubit>().load(widget.filter);
      _loadBranchNames();
    });
  }

  Future<void> _loadBranchNames() async {
    final branches = await context.read<AdminUsersCubit>().branches();
    if (mounted) {
      setState(() => _branchNames = {for (final b in branches) b.id: b.name});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text(widget.title, style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => context.read<AdminUsersCubit>().refresh(),
          ),
        ],
      ),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onAdd,
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.textDark,
              icon: const Icon(Icons.add_rounded),
              label: Text(widget.addLabel ?? 'Add',
                  style: AppTypography.label
                      .copyWith(color: AppColors.textDark)),
            ),
      body: BlocConsumer<AdminUsersCubit, AdminUsersState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          loaded: (users, busy) => _list(users, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(List<UserEntity> users, bool busy) {
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<AdminUsersCubit>().refresh(),
            child: users.isEmpty
                ? _empty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl * 2,
                    ),
                    children: [
                      for (final u in users)
                        AdminUserCard(
                          user: u,
                          branchLabel: u.branchId == null
                              ? null
                              : _branchNames[u.branchId],
                          actions: widget.actionsBuilder(context, u),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _empty() => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Text(widget.emptyMessage,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      );
}
