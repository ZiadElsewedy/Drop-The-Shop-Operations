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
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text('Home', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded,
                color: AppColors.textSecondary),
            onPressed: () => context.push(RouteNames.profile),
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            onPressed: () => context.push(RouteNames.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final user = state.maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );

          if (user == null) {
            return const SizedBox.shrink();
          }

          return _UserProfile(user: user);
        },
      ),
    );
  }
}

class _UserProfile extends StatelessWidget {
  const _UserProfile({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // Avatar + greeting
          Row(
            children: [
              _Avatar(initials: initials),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName != null && user.displayName!.isNotEmpty
                          ? 'Hello, ${user.displayName}!'
                          : 'Hello!',
                      style: AppTypography.h2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Welcome back', style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Profile card
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                if (user.displayName != null && user.displayName!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Display Name',
                    value: user.displayName!,
                    isFirst: true,
                  ),
                _InfoRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: user.email.isNotEmpty ? user.email : '—',
                  isFirst: user.displayName == null || user.displayName!.isEmpty,
                ),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  label: 'Sign-in Method',
                  value: _providerLabel(user.authProvider),
                  isLast: true,
                ),
              ],
            ),
          ),
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
      default:
        return provider;
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.fullAll,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.h2.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

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
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.lg,
          ),
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
                    Text(value, style: AppTypography.label),
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
