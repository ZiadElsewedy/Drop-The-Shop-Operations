import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings', style: AppTypography.h3),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final user = state.maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );
          final isEmailProvider = user?.authProvider == 'email';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // ── Account ──
                _SectionHeader(label: 'Account'),
                const SizedBox(height: AppSpacing.md),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      subtitle: user?.displayName ?? user?.email ?? '',
                      isFirst: true,
                      onTap: () => context.push(RouteNames.profile),
                    ),
                    if (isEmailProvider)
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change Password',
                        onTap: () => context.push(RouteNames.changePassword),
                      ),
                    if (isEmailProvider && user?.isEmailVerified == false)
                      _SettingsRow(
                        icon: Icons.mark_email_unread_outlined,
                        label: 'Verify Email',
                        subtitle: 'Your email is not yet verified',
                        subtitleColor: AppColors.warning,
                        onTap: () => context.push(RouteNames.emailVerification),
                      ),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      isLast: true,
                      onTap: () => context.read<AuthCubit>().signOut(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Security ──
                _SectionHeader(label: 'Security'),
                const SizedBox(height: AppSpacing.md),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete Account',
                      labelColor: AppColors.error,
                      iconColor: AppColors.error,
                      isFirst: true,
                      isLast: true,
                      onTap: () => _confirmDeleteAccount(context, isEmailProvider),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── About ──
                _SectionHeader(label: 'About'),
                const SizedBox(height: AppSpacing.md),
                _VersionRow(),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, bool isEmailProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DeleteAccountDialog(
        isEmailProvider: isEmailProvider,
        onConfirm: ({required String? password}) {
          context.read<AuthCubit>().deleteAccount(
                currentPassword: password,
              );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(letterSpacing: 1.2),
        ),
      );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
    this.iconColor,
    this.labelColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.darkBorder,
            indent: AppSpacing.pagePadding,
            endIndent: AppSpacing.pagePadding,
          ),
        InkWell(
          onTap: onTap,
          borderRadius: isFirst && isLast
              ? AppRadius.cardAll
              : isFirst
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.card))
                      : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18, color: iconColor ?? AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: AppTypography.label
                              .copyWith(color: labelColor)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: subtitleColor)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VersionRow extends StatefulWidget {
  @override
  State<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends State<_VersionRow> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    if (mounted) setState(() => _version = '1.0.0 (1)');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text('App Version',
                  style: AppTypography.label),
            ),
            Text(
              _version.isNotEmpty ? _version : '—',
              style: AppTypography.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final bool isEmailProvider;
  final void Function({required String? password}) onConfirm;

  const _DeleteAccountDialog({
    required this.isEmailProvider,
    required this.onConfirm,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      title: Text('Delete Account', style: AppTypography.h3),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action is permanent and cannot be undone. All your data will be deleted.',
            style: AppTypography.body,
          ),
          if (widget.isEmailProvider) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: AppTypography.body
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Confirm your password',
                labelStyle:
                    AppTypography.caption,
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide:
                      const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide:
                      const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: AppTypography.label
                  .copyWith(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm(
              password: widget.isEmailProvider
                  ? _passwordController.text
                  : null,
            );
          },
          child: Text('Delete',
              style:
                  AppTypography.label.copyWith(color: AppColors.error)),
        ),
      ],
    );
  }
}
