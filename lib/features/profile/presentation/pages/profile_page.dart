import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';
import 'package:drop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:drop/features/profile/presentation/cubit/profile_state.dart';
import 'package:drop/features/profile/presentation/widgets/profile_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final uid = context.currentUser?.uid;
    if (uid != null) context.read<ProfileCubit>().loadProfile(uid);
    // Branch directory for the assigned-branch section logo (§8b).
    context.read<BranchCubit>().loadIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: AppColors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Profile', style: AppTypography.h3),
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return state.maybeWhen(
            loading: () => const _ProfileSkeleton(),
            error: (msg) => _ErrorState(message: msg, onRetry: _load),
            orElse: () {
              final profile = state.maybeWhen(
                loaded: (p) => p,
                saving: (p, _) => p,
                saved: (p) => p,
                orElse: () => null,
              );
              if (profile == null) return const _ProfileSkeleton();
              return _ProfileContent(profile: profile);
            },
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileEntity profile;
  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Identity(profile: profile),
          const SizedBox(height: AppSpacing.xl),
          const _BranchSection(),
          _Group(children: _infoRows(profile)),
          const SizedBox(height: AppSpacing.lg),
          _Group(
            children: [
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                onTap: () => context.push(RouteNames.editProfile),
              ),
              _ActionTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => context.push(RouteNames.settings),
              ),
              _ActionTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                destructive: true,
                onTap: () => context.read<AuthCubit>().signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _infoRows(ProfileEntity p) {
    return [
      _InfoRow(label: 'Email', value: p.email.isNotEmpty ? p.email : '—'),
      if (p.phoneNumber != null && p.phoneNumber!.isNotEmpty)
        _InfoRow(label: 'Phone', value: p.phoneNumber!),
      _InfoRow(label: 'Sign-in', value: _provider(p.authProvider)),
      if (p.createdAt != null)
        _InfoRow(label: 'Member since', value: _date(p.createdAt!)),
    ];
  }

  String _provider(String p) {
    switch (p) {
      case 'email':
        return 'Email';
      case 'phone':
        return 'Phone';
      case 'google.com':
      case 'google':
        return 'Google';
      default:
        return p;
    }
  }

  String _date(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _Identity extends StatelessWidget {
  final ProfileEntity profile;
  const _Identity({required this.profile});

  @override
  Widget build(BuildContext context) {
    final incomplete = !profile.isComplete;
    return Row(
      children: [
        ProfileAvatar(
          initials: _initials(profile),
          imageUrl: profile.profileImage,
          size: 64,
          showRing: false,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: AppTypography.h2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (profile.handle.isNotEmpty)
                Text(profile.handle, style: AppTypography.body)
              else if (incomplete)
                GestureDetector(
                  onTap: () => context.push(RouteNames.editProfile),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Complete your profile', style: AppTypography.body),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.textTertiary),
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

/// The user's **assigned branch** (§8b) — logo + name + location. Renders
/// nothing for a user with no branch (e.g. a global admin). The branchId comes
/// from the auth session; identity is resolved via the app-wide [BranchCubit].
class _BranchSection extends StatelessWidget {
  const _BranchSection();

  @override
  Widget build(BuildContext context) {
    final branchId = context.currentUser?.branchId;
    if (branchId == null || branchId.isEmpty) return const SizedBox.shrink();
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, _) {
        final branch = context.read<BranchCubit>().branchById(branchId);
        final name = branch?.name ?? 'Your branch';
        final location = branch?.location ?? '';
        return Column(
          children: [
            AppGlassCard(
              child: Row(
                children: [
                  BranchAvatar(
                      logoUrl: branch?.logoUrl, name: name, size: 44, radius: 12),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ASSIGNED BRANCH',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                            )),
                        const SizedBox(height: 4),
                        Text(name,
                            style: AppTypography.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(location,
                              style: AppTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

/// A single grouped, hair-line-bordered list. Children are auto-divided.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1, thickness: 1, color: AppColors.darkBorder, indent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: AppTypography.body),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: destructive ? AppColors.error : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.label.copyWith(color: color))),
            if (!destructive)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

String _initials(ProfileEntity p) {
  final name = p.fullName?.trim();
  if (name != null && name.isNotEmpty) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }
  if (p.email.isNotEmpty) return p.email[0].toUpperCase();
  return '?';
}

// ─── Loading / error states ────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Skeleton(width: 64, height: 64, circle: true),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 160, height: 22),
                    SizedBox(height: 8),
                    Skeleton(width: 100, height: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          Skeleton(height: 150),
          SizedBox(height: AppSpacing.lg),
          Skeleton(height: 150),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: AppSpacing.lg),
            Text(message, textAlign: TextAlign.center, style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: Text('Try again',
                  style: AppTypography.label.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
