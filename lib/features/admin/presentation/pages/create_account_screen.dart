import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_dropdown_field.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/branch/domain/entities/branch_entity.dart';

/// Admin → User Management → **Create Account**. The admin-only provisioning
/// form. Account creation runs server-side (the `createUserAccount` Cloud
/// Function via the Admin SDK), so it never signs the admin out. On success the
/// admin is shown the temporary credentials to hand off.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _positionController = TextEditingController();

  UserRole _role = UserRole.employee;
  String? _branchId;
  String? _assignedShift; // null | 'morning' | 'night'
  List<BranchEntity> _branches = const [];
  bool _loadingBranches = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBranches());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final branches = await context.read<AdminUsersCubit>().branches();
    if (mounted) {
      setState(() {
        _branches = branches;
        _loadingBranches = false;
      });
    }
  }

  bool get _needsBranch => _role != UserRole.admin;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsBranch && (_branchId == null || _branchId!.isEmpty)) {
      AppSnackbar.error(context, 'Pick a branch for this account.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final email = _emailController.text.trim();
    final tempPassword = _passwordController.text;
    try {
      await context.read<AdminUsersCubit>().createAccount(
            name: _nameController.text.trim(),
            email: email,
            temporaryPassword: tempPassword,
            role: _role,
            branchId: _needsBranch ? _branchId : null,
            assignedShift: _assignedShift,
            position: _positionController.text.trim().isEmpty
                ? null
                : _positionController.text.trim(),
          );
      if (!mounted) return;
      await _showCredentials(email, tempPassword);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppSnackbar.error(
          context,
          e is Failure
              ? e.message
              : 'Could not create the account. Please try again.',
        );
      }
    }
  }

  Future<void> _showCredentials(String email, String password) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        title: Text('Account created', style: AppTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share these temporary credentials with the user. They will be '
              'asked to change the password on first sign-in.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _credLine('Email', email),
            const SizedBox(height: AppSpacing.sm),
            _credLine('Temporary password', password),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Done',
                style: AppTypography.label.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _credLine(String label, String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary, letterSpacing: 1)),
            const SizedBox(height: 2),
            SelectableText(value, style: AppTypography.label),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Create account', style: AppTypography.h3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.lg,
            AppSpacing.pagePadding, AppSpacing.xxxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Provision a new admin, manager or employee. The account is '
                'created securely on the server — you stay signed in.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),

              _label('Full name'),
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a full name' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('Email'),
              AppTextField(
                controller: _emailController,
                label: 'Email address',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Enter an email';
                  if (!t.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('Temporary password'),
              AppTextField(
                controller: _passwordController,
                label: 'Temporary password',
                hint: 'At least 6 characters',
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('Role'),
              AppDropdownField<UserRole>(
                value: _role,
                prefixIcon: Icons.badge_outlined,
                items: const [
                  DropdownMenuItem(
                      value: UserRole.employee, child: Text('Employee')),
                  DropdownMenuItem(
                      value: UserRole.manager, child: Text('Manager')),
                  DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                ],
                onChanged: (v) =>
                    setState(() => _role = v ?? UserRole.employee),
              ),
              const SizedBox(height: AppSpacing.lg),

              _label(_needsBranch ? 'Branch' : 'Branch (optional for admin)'),
              AppDropdownField<String?>(
                value: _branchId,
                hint: 'Select a branch',
                prefixIcon: Icons.store_mall_directory_outlined,
                placeholder: _loadingBranches
                    ? 'Loading branches…'
                    : (_branches.isEmpty ? 'No branches yet' : null),
                items: [
                  if (!_needsBranch)
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('No branch (global admin)')),
                  for (final b in _branches)
                    DropdownMenuItem<String?>(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => _branchId = v),
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('Assigned shift (optional)'),
              AppDropdownField<String?>(
                value: _assignedShift,
                hint: 'Select a shift',
                prefixIcon: Icons.schedule_rounded,
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('None')),
                  DropdownMenuItem<String?>(
                      value: 'morning', child: Text('Morning')),
                  DropdownMenuItem<String?>(
                      value: 'night', child: Text('Night')),
                ],
                onChanged: (v) => setState(() => _assignedShift = v),
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('Position (optional)'),
              AppTextField(
                controller: _positionController,
                label: 'Position',
                hint: 'e.g. Cashier',
                prefixIcon: Icons.work_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              AppButton(
                label: 'Create account',
                isLoading: _submitting,
                icon: _submitting
                    ? null
                    : const Icon(Icons.person_add_alt_1_rounded,
                        size: 20, color: AppColors.onPrimary),
                onPressed: _submitting ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
        child: Text(text.toUpperCase(),
            style: AppTypography.caption.copyWith(letterSpacing: 1.0)),
      );
}
