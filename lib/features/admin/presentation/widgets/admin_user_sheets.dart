import 'package:flutter/material.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';

Future<void> showApproveSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _ApproveSheet(cubit: cubit, user: user));

Future<void> showAssignBranchSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _AssignBranchSheet(cubit: cubit, user: user));

Future<void> showPromoteManagerSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
}) =>
    _sheet(context, _PromoteManagerSheet(cubit: cubit));

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pagePadding,
          right: AppSpacing.pagePadding,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: child,
      ),
    );

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Text(text, style: AppTypography.h3),
      );
}

/// Loads active branches and exposes a single-select list. [selected] is the
/// chosen branch id (null = none). Shows a leading "No branch" option.
class _BranchSelector extends StatefulWidget {
  const _BranchSelector({
    required this.cubit,
    required this.selected,
    required this.onChanged,
  });
  final AdminUsersCubit cubit;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  State<_BranchSelector> createState() => _BranchSelectorState();
}

class _BranchSelectorState extends State<_BranchSelector> {
  late final Future<List<BranchEntity>> _future = widget.cubit.branches();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchEntity>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final branches = snap.data ?? const [];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView(
            shrinkWrap: true,
            children: [
              _tile(label: 'No branch', value: null),
              for (final b in branches)
                _tile(
                  label: b.location == null || b.location!.isEmpty
                      ? b.name
                      : '${b.name} · ${b.location}',
                  value: b.id,
                ),
              if (branches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No active branches yet — create one first.',
                      style: AppTypography.caption),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile({required String label, required String? value}) {
    final selected = widget.selected == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.textTertiary,
        size: 20,
      ),
      title: Text(label, style: AppTypography.label),
      onTap: () => widget.onChanged(value),
    );
  }
}

// ─── Approve ─────────────────────────────────────────────────────
class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  UserRole _role = UserRole.employee;
  late String? _branchId = widget.user.branchId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Approve user'),
          Text(widget.user.email, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Text('Role', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _RolePill(
                label: 'Employee',
                selected: _role == UserRole.employee,
                onTap: () => setState(() => _role = UserRole.employee),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RolePill(
                label: 'Manager',
                selected: _role == UserRole.manager,
                onTap: () => setState(() => _role = UserRole.manager),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Branch', style: AppTypography.caption),
          _BranchSelector(
            cubit: widget.cubit,
            selected: _branchId,
            onChanged: (v) => setState(() => _branchId = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Approve',
            icon: const Icon(Icons.check_circle_outline_rounded,
                size: 20, color: AppColors.textDark),
            onPressed: () {
              widget.cubit
                  .approve(widget.user, role: _role, branchId: _branchId);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: 'Reject',
            onPressed: () {
              widget.cubit.reject(widget.user);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.darkSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.textDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Assign / change branch ──────────────────────────────────────
class _AssignBranchSheet extends StatefulWidget {
  const _AssignBranchSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_AssignBranchSheet> createState() => _AssignBranchSheetState();
}

class _AssignBranchSheetState extends State<_AssignBranchSheet> {
  late String? _branchId = widget.user.branchId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Assign branch'),
        _BranchSelector(
          cubit: widget.cubit,
          selected: _branchId,
          onChanged: (v) => setState(() => _branchId = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          onPressed: () {
            widget.cubit.changeBranch(widget.user, _branchId);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ─── Promote employee → manager ──────────────────────────────────
class _PromoteManagerSheet extends StatefulWidget {
  const _PromoteManagerSheet({required this.cubit});
  final AdminUsersCubit cubit;
  @override
  State<_PromoteManagerSheet> createState() => _PromoteManagerSheetState();
}

class _PromoteManagerSheetState extends State<_PromoteManagerSheet> {
  late final Future<List<UserEntity>> _future =
      widget.cubit.promotableEmployees();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Add manager'),
        Text('Promote an approved employee to manager. Assign their branch '
            'afterwards from the manager list.',
            style: AppTypography.caption),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<UserEntity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final employees = snap.data ?? const [];
            if (employees.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No approved employees to promote.',
                    style: AppTypography.bodySmall),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: employees.length,
                itemBuilder: (context, i) {
                  final u = employees[i];
                  final name = (u.displayName != null &&
                          u.displayName!.isNotEmpty)
                      ? u.displayName!
                      : u.email;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded,
                        color: AppColors.primary),
                    title: Text(name, style: AppTypography.label),
                    subtitle: Text(u.email, style: AppTypography.caption),
                    onTap: () {
                      widget.cubit.promoteToManager(u);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
