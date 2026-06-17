import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_bottom_nav.dart';
import 'package:fbro/core/widgets/user_avatar.dart';
import 'package:fbro/core/extensions/context_extensions.dart';

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
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Notifications',
            onPressed: () => context
                .showSuccess("You're all caught up — no new notifications."),
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
