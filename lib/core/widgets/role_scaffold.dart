import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';

/// Shared chrome for every role shell (admin / manager / employee).
///
/// Hosts the role's screen as [child] and exposes the cross-role actions —
/// profile, settings and sign-out. Each role keeps its own Shell so future
/// phases can diverge (e.g. per-role bottom navigation) without rewriting this
/// chrome.
class RoleScaffold extends StatelessWidget {
  const RoleScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text(title, style: AppTypography.h3),
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
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary),
            onPressed: () => context.read<AuthCubit>().signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: child,
    );
  }
}
