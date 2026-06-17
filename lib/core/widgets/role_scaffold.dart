import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/core/widgets/app_dialog.dart';

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
            icon: const Icon(Icons.fact_check_outlined,
                color: AppColors.textSecondary),
            onPressed: () {
              // Dispatch to the caller's role-appropriate task screen (admin:
              // all branches · manager: own branch · employee: own tasks).
              final role = context.currentRole;
              if (role != null) context.push(RouteNames.tasksForRole(role));
            },
            tooltip: 'Tasks',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_week_outlined,
                color: AppColors.textSecondary),
            onPressed: () {
              // Dispatch to the caller's role-appropriate weekly-schedule screen
              // (admin: any branch · manager: own branch · employee: own branch).
              final role = context.currentRole;
              if (role != null) context.push(RouteNames.scheduleForRole(role));
            },
            tooltip: 'Schedule',
          ),
          // Occasional actions live in a single overflow menu so the app bar
          // stays uncluttered and Sign out can't be triggered by an accidental
          // tap (it now requires opening the menu + confirming).
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            color: AppColors.darkSurfaceElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.push(RouteNames.profile);
                case 'settings':
                  context.push(RouteNames.settings);
                case 'signout':
                  _confirmSignOut(context);
              }
            },
            itemBuilder: (context) => [
              _menuItem('profile', Icons.person_outline_rounded, 'Profile'),
              _menuItem('settings', Icons.settings_outlined, 'Settings'),
              const PopupMenuDivider(),
              _menuItem('signout', Icons.logout_rounded, 'Sign out',
                  danger: true),
            ],
          ),
        ],
      ),
      body: child,
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {bool danger = false}) {
    final color = danger ? AppColors.error : AppColors.textPrimary;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: AppTypography.label.copyWith(color: color)),
        ],
      ),
    );
  }

  /// Confirms before clearing the session — signing out is destructive of any
  /// in-progress work and forces a re-login, so it should never be one tap.
  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthCubit>(); // capture before the async gap
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: "You'll need to sign in again to access your account.",
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (confirmed) auth.signOut();
  }
}
