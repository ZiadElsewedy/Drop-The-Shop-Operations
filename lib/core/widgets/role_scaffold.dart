import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_bottom_nav.dart';
import 'package:drop/core/widgets/desktop_nav_sidebar.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';

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
    final role = context.currentRole ?? UserRole.employee;
    // Desktop / macOS: persistent sidebar chrome. Mobile / tablet: the original
    // app bar + bottom-nav layout, untouched.
    return context.isDesktop
        ? _buildDesktop(context, role)
        : _buildMobile(context, role);
  }

  // ─── Mobile / tablet ───────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context, UserRole role) {
    final user = context.currentUser;
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

  // ─── Desktop / ultrawide (macOS) ─────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context, UserRole role) {
    final user = context.currentUser;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopNavSidebar(
            items: _items,
            currentIndex: 0,
            onTap: (i) => _onNavTap(context, i),
            footer: _SidebarUserFooter(
              user: user,
              role: role,
              onTap: () => context.push(RouteNames.profile),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _DesktopTopBar(
                  title: title,
                  showCommunications: role.isAdmin || role.isManager,
                  onCommunications: () => context.push(RouteNames.communications),
                  onNotifications: () => context.push(RouteNames.notifications),
                ),
                const Divider(height: 1, color: AppColors.darkBorder),
                Expanded(
                  child: ContentConstraint(child: child),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The slim desktop header bar that replaces the mobile [AppBar]: a large,
/// confident page title on the left and the global actions on the right.
class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.showCommunications,
    required this.onCommunications,
    required this.onNotifications,
  });

  final String title;
  final bool showCommunications;
  final VoidCallback onCommunications;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      color: AppColors.darkBg,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.h2)),
          if (showCommunications)
            IconButton(
              icon: const Icon(Icons.campaign_outlined,
                  color: AppColors.textSecondary),
              tooltip: 'Communications',
              onPressed: onCommunications,
            ),
          _NotificationBell(onPressed: onNotifications),
        ],
      ),
    );
  }
}

/// Pinned sidebar footer: avatar + name + role, tappable → profile.
class _SidebarUserFooter extends StatefulWidget {
  const _SidebarUserFooter({
    required this.user,
    required this.role,
    required this.onTap,
  });

  final UserEntity? user;
  final UserRole role;
  final VoidCallback onTap;

  @override
  State<_SidebarUserFooter> createState() => _SidebarUserFooterState();
}

class _SidebarUserFooterState extends State<_SidebarUserFooter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0x12FFFFFF) : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              user != null
                  ? UserAvatar.fromUser(user, size: 36)
                  : const UserAvatar(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (user?.displayName?.isNotEmpty ?? false)
                          ? user!.displayName!
                          : 'Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label,
                    ),
                    Text(
                      widget.role.name.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        letterSpacing: 1,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
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
