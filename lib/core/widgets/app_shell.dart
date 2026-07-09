import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_sidebar.dart';
import 'package:drop/core/widgets/command_palette.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';

/// The desktop application shell — the single source of persistent navigation
/// chrome for the whole signed-in app.
///
/// Wired into the router as a [ShellRoute] so the [AppSidebar] is mounted **once**
/// and survives every route change (no re-animation, no flicker) — the structural
/// difference between a real macOS productivity app and a stack of pushed mobile
/// screens. On mobile/tablet the shell is a no-op pass-through: those widths keep
/// the original per-screen app bars + bottom navigation untouched.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current router location (from `GoRouterState.matchedLocation`).
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Mobile / tablet: unchanged. Also bail out if we somehow render without a
    // session (the router's redirect guards normally prevent this).
    final user = context.currentUser;
    if (!context.isDesktop || user == null) return child;

    final role = user.role;
    final sections = sectionsForRole(role);
    final destinations = [for (final s in sections) ...s.items];
    // ⌘1…⌘9 jump straight to the Nth sidebar destination and ⌘K opens the
    // command palette — the baseline keyboard navigation a native macOS
    // productivity app is expected to have. CallbackShortcuts fires whenever
    // focus is anywhere in the subtree; meta combos never insert text, so
    // they're safe while typing.
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < destinations.length && i < _digitKeys.length; i++)
          SingleActivator(_digitKeys[i], meta: true): () {
            final route = destinations[i].route;
            if (route != location) context.go(route);
          },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context, user: user, sections: sections),
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.darkBg,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSidebar(
                sections: sections,
                location: location,
                onSelect: (route) {
                  if (route != location) context.go(route);
                },
                footer: _SidebarUserFooter(
                  user: user,
                  role: role,
                  onTap: () => context.go(RouteNames.profile),
                ),
              ),
              // The child is go_router's shell Navigator — ONE widget with a
              // GlobalKey. It must never be wrapped in anything that mounts
              // it twice (AnimatedSwitcher, cross-fades, keyed swaps): that
              // duplicates the GlobalKey mid-transition, corrupts the element
              // tree, and froze all navigation on macOS. The desktop fade
              // between destinations already exists at the PAGE level (every
              // shell route's CustomTransitionPage fades on ≥1024pt), so no
              // shell-level animation is needed.
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// The role's sidebar destinations — public so the ⌘K command palette can
  /// present the same list with the same ⌘n ordering.
  static List<SidebarSection> sectionsForRole(UserRole role) {
    const notifications = SidebarItem(
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
      label: 'Notifications',
      route: RouteNames.notifications,
    );
    const communications = SidebarItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      label: 'Communications',
      route: RouteNames.communications,
    );
    const cases = SidebarItem(
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'Cases',
      route: RouteNames.cases,
    );
    const requests = SidebarItem(
      icon: Icons.approval_outlined,
      activeIcon: Icons.approval_rounded,
      label: 'Requests',
      route: RouteNames.requests,
    );
    const community = SidebarItem(
      icon: Icons.celebration_outlined,
      activeIcon: Icons.celebration_rounded,
      label: 'Community',
      route: RouteNames.community,
    );

    switch (role) {
      case UserRole.admin:
        return [
          const SidebarSection(items: [
            SidebarItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: RouteNames.adminDashboard,
            ),
            SidebarItem(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'Tasks',
              route: RouteNames.adminTasks,
            ),
            SidebarItem(
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'Schedule',
              route: RouteNames.adminSchedule,
            ),
            communications,
            cases,
            requests,
            community,
            notifications,
          ]),
          const SidebarSection(title: 'Administration', items: [
            SidebarItem(
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics_rounded,
              label: 'Analytics',
              route: RouteNames.adminAnalytics,
            ),
            SidebarItem(
              icon: Icons.store_outlined,
              activeIcon: Icons.store_rounded,
              label: 'Branches',
              route: RouteNames.adminBranches,
            ),
            SidebarItem(
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge_rounded,
              label: 'Managers',
              route: RouteNames.adminManagers,
            ),
            SidebarItem(
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: 'Employees',
              route: RouteNames.adminEmployees,
            ),
          ]),
        ];
      case UserRole.manager:
        return [
          const SidebarSection(items: [
            SidebarItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: RouteNames.managerHome,
            ),
            SidebarItem(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'Operations',
              route: RouteNames.managerTasks,
            ),
            SidebarItem(
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'Schedule',
              route: RouteNames.managerSchedule,
            ),
            communications,
            cases,
            requests,
            community,
            notifications,
          ]),
        ];
      case UserRole.employee:
        return [
          const SidebarSection(items: [
            SidebarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              route: RouteNames.home,
            ),
            SidebarItem(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'My Tasks',
              route: RouteNames.myTasks,
            ),
            SidebarItem(
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'My Schedule',
              route: RouteNames.mySchedule,
            ),
            cases,
            requests,
            community,
            notifications,
          ]),
        ];
    }
  }
}

/// Pinned sidebar footer: unread-aware avatar + name + role, tappable → profile.
class _SidebarUserFooter extends StatefulWidget {
  const _SidebarUserFooter({
    required this.user,
    required this.role,
    required this.onTap,
  });

  final UserEntity user;
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
    final name = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName!
        : 'Profile';
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
              UserAvatar.fromUser(user, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
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
              const _FooterBell(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small unread-count indicator in the footer so notifications are glanceable
/// even when the inbox isn't the active destination.
class _FooterBell extends StatelessWidget {
  const _FooterBell();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, _) {
        final unread = context.read<NotificationCubit>().unreadCount;
        if (unread <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            unread > 9 ? '9+' : '$unread',
            style: AppTypography.caption.copyWith(
              color: AppColors.onAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
