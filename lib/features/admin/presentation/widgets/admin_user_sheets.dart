import 'package:flutter/material.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';

Future<void> showResetAccountSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _ResetAccountSheet(cubit: cubit, user: user));

Future<void> showEmploymentStatusSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _EmploymentStatusSheet(cubit: cubit, user: user));

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

Future<void> showSetPositionSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _SetPositionSheet(cubit: cubit, user: user));

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

// ─── Reset account (new temp password + re-force change) ─────────
class _ResetAccountSheet extends StatefulWidget {
  const _ResetAccountSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_ResetAccountSheet> createState() => _ResetAccountSheetState();
}

class _ResetAccountSheetState extends State<_ResetAccountSheet> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final value = _password.text.trim();
    if (value.length < 6) return;
    widget.cubit.resetAccount(widget.user, value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Reset account'),
          Text(
            'Set a new temporary password for ${widget.user.email}. They will be '
            'forced to change it on next sign-in.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _password,
            label: 'Temporary password',
            hint: 'At least 6 characters',
            prefixIcon: Icons.lock_reset_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Reset account', onPressed: _save),
        ],
      ),
    );
  }
}

// ─── Employment status (HR label) ────────────────────────────────
class _EmploymentStatusSheet extends StatelessWidget {
  const _EmploymentStatusSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;

  static const _options = ['active', 'suspended', 'terminated'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Employment status'),
        Text(
          'An HR record label. It does not block access on its own — use '
          'Deactivate to revoke sign-in.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final s in _options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              user.employmentStatus == s
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: user.employmentStatus == s
                  ? AppColors.primary
                  : AppColors.textTertiary,
              size: 20,
            ),
            title: Text(
              '${s[0].toUpperCase()}${s.substring(1)}',
              style: AppTypography.label,
            ),
            onTap: () {
              cubit.changeEmploymentStatus(user, s);
              Navigator.of(context).pop();
            },
          ),
      ],
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

// ─── Set job position ────────────────────────────────────────────
class _SetPositionSheet extends StatefulWidget {
  const _SetPositionSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_SetPositionSheet> createState() => _SetPositionSheetState();
}

class _SetPositionSheetState extends State<_SetPositionSheet> {
  late final _position =
      TextEditingController(text: widget.user.position ?? '');

  // Common retail positions — quick-fill chips (free text still allowed).
  static const _suggestions = ['Cashier', 'Supervisor', 'Stockist', 'Greeter'];

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _save() {
    final value = _position.text.trim();
    widget.cubit.changePosition(widget.user, value.isEmpty ? null : value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Job position'),
          Text(
              'Drives shift-swap role compatibility when a branch requires '
              'same-role swaps. Leave empty for none.',
              style: AppTypography.caption),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _position,
            label: 'Position',
            hint: 'e.g. Cashier',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in _suggestions)
                GestureDetector(
                  onTap: () => setState(() {
                    _position.text = s;
                    _position.selection = TextSelection.collapsed(
                        offset: _position.text.length);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Text(s, style: AppTypography.caption),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Save', onPressed: _save),
        ],
      ),
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
        const _Title('Promote to manager'),
        Text('Promote an existing employee to manager. Their current branch is '
            'kept — reassign it from the manager list if needed.',
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
                child: Text('No employees to promote.',
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
                    leading: UserAvatar.fromUser(u, size: 40),
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
