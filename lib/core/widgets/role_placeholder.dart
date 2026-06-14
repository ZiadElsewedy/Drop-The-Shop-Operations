import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';

/// Functional (not-yet-designed) placeholder body for the admin/manager role
/// screens scaffolded in Phase 1. Renders the role's heading plus the signed-in
/// user's name, role and branch so end-to-end role routing is verifiable now;
/// real content lands in later phases.
class RolePlaceholder extends StatelessWidget {
  const RolePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.maybeWhen(
          authenticated: (u) => u,
          orElse: () => null,
        );

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppColors.textTertiary),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (user != null) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: AppRadius.cardAll,
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Text(
                      '${user.displayName ?? user.email}  ·  '
                      '${user.role.value}  ·  '
                      '${(user.branchId != null && user.branchId!.isNotEmpty) ? user.branchId! : 'no branch'}',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
