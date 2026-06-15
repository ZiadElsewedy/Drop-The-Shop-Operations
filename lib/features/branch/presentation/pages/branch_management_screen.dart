import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_state.dart';
import 'package:fbro/features/branch/presentation/widgets/branch_form_sheet.dart';

/// Admin → Branches. Create, edit, activate/deactivate and (soft) delete
/// branches.
class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<BranchCubit>().load());
  }

  Future<void> _confirmDelete(BranchEntity branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text('Delete branch?', style: AppTypography.h3),
        content: Text(
          '"${branch.name}" will be archived (soft delete). Existing shifts, '
          'tasks and user assignments are kept.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<BranchCubit>().deleteBranch(branch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Branches', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => context.read<BranchCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBranchFormSheet(
          context: context,
          cubit: context.read<BranchCubit>(),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Branch',
            style: AppTypography.label.copyWith(color: AppColors.textDark)),
      ),
      body: BlocConsumer<BranchCubit, BranchState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          loaded: (branches, busy) => _list(branches, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(List<BranchEntity> branches, bool busy) {
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<BranchCubit>().load(),
            child: branches.isEmpty
                ? _empty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl * 2,
                    ),
                    children: [for (final b in branches) _card(b)],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _card(BranchEntity branch) {
    final cubit = context.read<BranchCubit>();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(branch.name, style: AppTypography.label)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (branch.isActive ? AppColors.success : AppColors.error)
                      .withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  branch.isActive ? 'active' : 'inactive',
                  style: AppTypography.caption.copyWith(
                    color: branch.isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if ((branch.location ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(branch.location!, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _btn('Edit', Icons.edit_outlined,
                  () => showBranchFormSheet(
                      context: context, cubit: cubit, existing: branch)),
              _btn(
                branch.isActive ? 'Deactivate' : 'Activate',
                branch.isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                () => cubit.setActive(branch, !branch.isActive),
                color: branch.isActive ? AppColors.error : AppColors.success,
              ),
              _btn('Delete', Icons.delete_outline_rounded,
                  () => _confirmDelete(branch),
                  color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.primary,
        backgroundColor: AppColors.darkSurfaceElevated,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        textStyle: AppTypography.caption,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
                child: Text('No branches yet.\nTap "New Branch" to add one.',
                    style: AppTypography.bodySmall, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      );
}
