import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fbro/features/profile/presentation/cubit/profile_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthCubit>().state.maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );
      if (user != null) {
        context.read<ProfileCubit>().loadProfile(user.uid);
      }
    });
  }

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
        title: Text('Profile', style: AppTypography.h3),
        actions: [
          BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final user = state.maybeWhen(
                loaded: (u) => u,
                updated: (u) => u,
                orElse: () => null,
              );
              if (user == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                onPressed: () => context.push(RouteNames.editProfile),
                tooltip: 'Edit Profile',
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, profileState) {
          return profileState.when(
            initial: () => const SizedBox.shrink(),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            updating: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            loaded: (user) => _ProfileContent(user: user),
            updated: (user) => _ProfileContent(user: user),
            error: (msg) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 40),
                    const SizedBox(height: AppSpacing.lg),
                    Text(msg,
                        textAlign: TextAlign.center,
                        style: AppTypography.body),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final UserEntity user;
  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Avatar + name
          Center(
            child: Column(
              children: [
                _Avatar(initials: initials, photoUrl: user.photoUrl),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  user.displayName?.isNotEmpty == true
                      ? user.displayName!
                      : 'No name set',
                  style: AppTypography.h2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(user.email, style: AppTypography.body),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          _SectionLabel(label: 'Account Information'),
          const SizedBox(height: AppSpacing.md),

          Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Display Name',
                  value: user.displayName?.isNotEmpty == true
                      ? user.displayName!
                      : '—',
                  isFirst: true,
                ),
                _InfoRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: user.email.isNotEmpty ? user.email : '—',
                ),
                if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: user.phoneNumber!,
                  ),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  label: 'Sign-in Method',
                  value: _providerLabel(user.authProvider),
                ),
                _InfoRow(
                  icon: Icons.verified_outlined,
                  label: 'Email Verified',
                  value: user.isEmailVerified ? 'Verified' : 'Not verified',
                  valueColor: user.isEmailVerified
                      ? AppColors.success
                      : AppColors.warning,
                ),
                if (user.createdAt != null)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member Since',
                    value: _formatDate(user.createdAt!),
                    isLast: true,
                  )
                else
                  _InfoRow(
                    icon: Icons.tag_rounded,
                    label: 'User ID',
                    value: '${user.uid.substring(0, 8)}…',
                    isLast: true,
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          _SectionLabel(label: 'Actions'),
          const SizedBox(height: AppSpacing.md),

          Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  isFirst: true,
                  onTap: () => context.push(RouteNames.editProfile),
                ),
                _ActionRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isLast: true,
                  onTap: () => context.push(RouteNames.settings),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Sign out
          _ActionRow(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            iconColor: AppColors.error,
            labelColor: AppColors.error,
            standalone: true,
            onTap: () => context.read<AuthCubit>().signOut(),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _initials(UserEntity user) {
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      final parts = user.displayName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }
    if (user.email.isNotEmpty) return user.email[0].toUpperCase();
    return '?';
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'email':
        return 'Email & Password';
      case 'phone':
        return 'Phone Number';
      case 'google.com':
      case 'google':
        return 'Google';
      default:
        return provider;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;

  const _Avatar({required this.initials, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.fullAll,
      ),
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: AppRadius.fullAll,
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initialsWidget,
              ),
            )
          : _initialsWidget,
    );
  }

  Widget get _initialsWidget => Center(
        child: Text(
          initials,
          style: AppTypography.h2.copyWith(color: AppColors.white),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(label.toUpperCase(),
            style: AppTypography.caption.copyWith(letterSpacing: 1.2)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          Divider(height: 1, thickness: 1, color: AppColors.darkBorder,
              indent: AppSpacing.pagePadding, endIndent: AppSpacing.pagePadding),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding, vertical: AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.caption),
                    const SizedBox(height: 2),
                    Text(value,
                        style: AppTypography.label.copyWith(
                            color: valueColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool isFirst;
  final bool isLast;
  final bool standalone;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.isFirst = false,
    this.isLast = false,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      borderRadius: standalone
          ? AppRadius.cardAll
          : isFirst
              ? const BorderRadius.vertical(top: Radius.circular(AppRadius.card))
              : isLast
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.card))
                  : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding, vertical: AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label,
                  style: AppTypography.label
                      .copyWith(color: labelColor ?? AppColors.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );

    if (standalone) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: row,
      );
    }

    return Column(
      children: [
        if (!isFirst)
          Divider(height: 1, thickness: 1, color: AppColors.darkBorder,
              indent: AppSpacing.pagePadding, endIndent: AppSpacing.pagePadding),
        row,
      ],
    );
  }
}
