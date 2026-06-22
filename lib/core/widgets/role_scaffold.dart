import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_bottom_nav.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/core/extensions/context_extensions.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_state.dart';

/// Shared chrome for every role shell (admin / manager / employee).
///
/// Hosts the role's dashboard as [child] under a clean header (notification bell
/// + tappable avatar → profile) and the DROP bottom navigation bar
/// (Home · Tasks · Schedule · Profile). The cross-role destinations
/// (tasks / schedule / profile, which carry settings + sign-out) are reached
/// from the bottom nav; each pushes its dedicated role-scoped screen.
class RoleScaffold extends StatelessWidget {
  const RoleScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const List<AppNavItem> _items = [
    AppNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    AppNavItem(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      label: 'Tasks',
    ),
    AppNavItem(
      icon: Icons.calendar_view_week_outlined,
      activeIcon: Icons.calendar_view_week_rounded,
      label: 'Schedule',
    ),
    AppNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _onNavTap(BuildContext context, int index) {
    final role = context.currentRole;
    if (role == null) return;
    switch (index) {
      case 0:
        break; // Already on the role home.
      case 1:
        context.push(RouteNames.tasksForRole(role));
      case 2:
        context.push(RouteNames.scheduleForRole(role));
      case 3:
        context.push(RouteNames.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    final role = context.currentRole ?? UserRole.employee;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        titleSpacing: 24,
        title: Text(title, style: AppTypography.h3),
        actions: [
          // Communications Center — admin + manager only (employees can't access).
          if (role.isAdmin || role.isManager)
            IconButton(
              icon: const Icon(Icons.campaign_outlined,
                  color: AppColors.textSecondary),
              tooltip: 'Communications',
              onPressed: () => context.push(RouteNames.communications),
            ),
          _NotificationBell(
            onPressed: () => context.push(RouteNames.notifications),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => context.push(RouteNames.profile),
              child: user != null
                  ? UserAvatar.fromUser(user, size: 36, ringColor: role.isGlobal
                      ? AppColors.primary
                      : AppColors.darkBorder)
                  : const UserAvatar(size: 36),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: 0,
        onTap: (i) => _onNavTap(context, i),
      ),
    );
  }
}

/// The header notification bell with an unread-count dot (Notification System
/// Phase 1). Reads [NotificationCubit] for the unread count.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, _) {
        final unread = context.read<NotificationCubit>().unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded,
                  color: AppColors.textSecondary),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.darkBg, width: 1.5),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
