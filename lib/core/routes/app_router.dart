import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/pages/splash_page.dart';
import 'package:fbro/features/auth/presentation/pages/login_page.dart';
import 'package:fbro/features/auth/presentation/pages/register_page.dart';
import 'package:fbro/features/auth/presentation/pages/phone_otp_page.dart';
import 'package:fbro/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:fbro/features/auth/presentation/pages/email_verification_page.dart';
import 'package:fbro/features/auth/presentation/pages/pending_approval_page.dart';
import 'package:fbro/features/admin/presentation/pages/admin_shell.dart';
import 'package:fbro/features/manager/presentation/pages/manager_shell.dart';
import 'package:fbro/features/employee/presentation/pages/employee_shell.dart';
import 'package:fbro/features/task/presentation/pages/task_management_screen.dart';
import 'package:fbro/features/task/presentation/pages/my_tasks_screen.dart';
import 'package:fbro/features/task/presentation/pages/task_detail_loader_screen.dart';
import 'package:fbro/features/operations/presentation/pages/manager_operations_screen.dart';
import 'package:fbro/features/schedule/presentation/pages/schedule_management_screen.dart';
import 'package:fbro/features/schedule/presentation/pages/branch_schedule_screen.dart';
import 'package:fbro/features/schedule/presentation/pages/my_schedule_screen.dart';
import 'package:fbro/features/branch/presentation/pages/branch_management_screen.dart';
import 'package:fbro/features/admin/presentation/pages/manager_management_screen.dart';
import 'package:fbro/features/admin/presentation/pages/employee_management_screen.dart';
import 'package:fbro/features/admin/presentation/pages/admin_analytics_screen.dart';
import 'package:fbro/features/admin/presentation/pages/pending_approvals_screen.dart';
import 'package:fbro/features/profile/presentation/pages/profile_page.dart';
import 'package:fbro/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:fbro/features/settings/presentation/pages/settings_page.dart';
import 'package:fbro/features/settings/presentation/pages/change_password_page.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/presentation/pages/communications_screen.dart';
import 'package:fbro/features/communications/presentation/pages/compose_broadcast_screen.dart';
import 'package:fbro/features/communications/presentation/pages/broadcast_detail_screen.dart';
import 'package:fbro/features/communications/presentation/pages/broadcast_templates_screen.dart';
import 'package:fbro/features/communications/presentation/pages/broadcast_schedules_screen.dart';
import 'package:fbro/features/notifications/presentation/pages/notifications_screen.dart';
import 'route_names.dart';

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: _AuthStateNotifier(authCubit),
    redirect: (BuildContext context, GoRouterState state) {
      final loc = state.matchedLocation;

      if (loc == RouteNames.splash) return null;

      final authState = authCubit.state;

      final user = authState.maybeWhen(
        authenticated: (u) => u,
        orElse: () => null,
      );
      final isAuthenticated = user != null;

      final isAwaitingVerification = authState.maybeWhen(
        awaitingEmailVerification: (_) => true,
        orElse: () => false,
      );

      final isOnAuthFlow = loc == RouteNames.login ||
          loc == RouteNames.register ||
          loc == RouteNames.phone ||
          loc == RouteNames.forgotPassword;

      if (isAwaitingVerification && loc != RouteNames.emailVerification) {
        // go_router redirect doesn't support extra — navigation is handled by
        // the BlocListener in each auth page and SplashPage instead.
        return RouteNames.emailVerification;
      }

      if (isAuthenticated) {
        // Approval gate (checked before role dispatch). DROP is an internal ops
        // system: an authenticated account that hasn't been approved — or has
        // been deactivated — is confined to the Pending Approval screen until a
        // manager/admin approves it. Sign-out is the only way off the screen.
        if (!user.hasAppAccess) {
          return loc == RouteNames.pendingApproval
              ? null
              : RouteNames.pendingApproval;
        }

        final roleHome = RouteNames.homeForRole(user.role);

        // Role guard. Admin ⊇ manager: admin areas are admin-only, but manager
        // areas admit admins too (admin can do everything a manager can). The
        // employee home (/) is employee-only. Anyone landing in an area that
        // isn't theirs (incl. manual URL hacking) is bounced to their own home.
        // Shared routes (/profile, /settings) stay open to all roles.
        if (_isAdminArea(loc) && !user.role.isAdmin) return roleHome;
        if (_isManagerArea(loc) && !(user.role.isManager || user.role.isAdmin)) {
          return roleHome;
        }
        // Communications Center is admin + manager only; employees are bounced.
        if (_isCommunicationsArea(loc) && user.role.isEmployee) {
          return roleHome;
        }
        if (loc == RouteNames.home && !user.role.isEmployee) {
          return roleHome;
        }

        // Approved users never see the auth flow / verification / pending
        // screens → bounce them to their role home.
        if (isOnAuthFlow ||
            loc == RouteNames.emailVerification ||
            loc == RouteNames.pendingApproval) {
          return roleHome;
        }

        return null;
      }

      // Unauthenticated → confine to the auth flow; the landing screen is Login
      // (the old social Welcome page has been removed).
      if (!isAwaitingVerification && !isOnAuthFlow) {
        if (loc != RouteNames.splash) return RouteNames.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.pendingApproval,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const PendingApprovalPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.home,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const EmployeeShell(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminDashboard,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const AdminShell(),
        ),
      ),
      GoRoute(
        path: RouteNames.managerHome,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const ManagerShell(),
        ),
      ),
      // ─── Tasks (Phase 3) ───────────────────────────────────────
      // Guarded like the rest: /admin/tasks is admin-only, /manager/tasks admits
      // manager + admin; /my-tasks is self-scoped.
      GoRoute(
        path: RouteNames.adminTasks,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const TaskManagementScreen(),
        ),
      ),
      // Manager "Operations" tab → the Branch Operations cockpit for the
      // manager's own branch (the task→operations redesign; the full per-branch
      // task list is now reached via the cockpit's "All tasks" → BranchTaskListScreen).
      GoRoute(
        path: RouteNames.managerTasks,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ManagerOperationsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.myTasks,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const MyTasksScreen(),
        ),
      ),
      // Exact-task deep-link (every role) — a task notification lands here.
      GoRoute(
        path: RouteNames.taskDetailPattern,
        pageBuilder: (context, state) => _slideTransition(
          state,
          TaskDetailLoaderScreen(taskId: state.pathParameters['taskId'] ?? ''),
        ),
      ),
      // ─── Weekly schedule (Phase 7) ─────────────────────────────
      // Guarded like tasks: /admin/schedule is admin-only, /manager/schedule
      // admits manager + admin; /my-schedule is self-scoped (own branch).
      GoRoute(
        path: RouteNames.adminSchedule,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ScheduleManagementScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.managerSchedule,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const BranchScheduleScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.mySchedule,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const MyScheduleScreen(),
        ),
      ),
      // ─── Admin module (Phase 5) ────────────────────────────────
      // All under /admin/*, covered by the admin-only `_isAdminArea` guard.
      GoRoute(
        path: RouteNames.adminBranches,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const BranchManagementScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminManagers,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ManagerManagementScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminEmployees,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const EmployeeManagementScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminAnalytics,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const AdminAnalyticsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminApprovals,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const PendingApprovalsScreen(),
        ),
      ),
      // ─── Communications Center (Phase 3) ───────────────────────
      // admin + manager (employees blocked by `_isCommunicationsArea`). The
      // static `/compose` route is declared BEFORE the `:broadcastId` detail
      // route so it is never captured as an id.
      GoRoute(
        path: RouteNames.communications,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const CommunicationsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.communicationsCompose,
        pageBuilder: (context, state) => _slideTransition(
          state,
          ComposeBroadcastScreen(
            prefill:
                state.extra is BroadcastEntity ? state.extra as BroadcastEntity : null,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.communicationsTemplates,
        pageBuilder: (context, state) => _slideTransition(
          state,
          BroadcastTemplatesScreen(pickMode: state.extra == 'pick'),
        ),
      ),
      GoRoute(
        path: RouteNames.communicationsSchedules,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const BroadcastSchedulesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.communicationsDetailPattern,
        pageBuilder: (context, state) => _slideTransition(
          state,
          BroadcastDetailScreen(
            broadcastId: state.pathParameters['broadcastId'] ?? '',
            broadcast: state.extra is BroadcastEntity
                ? state.extra as BroadcastEntity
                : null,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const LoginPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const RegisterPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.phone,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const PhoneOtpPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.emailVerification,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const EmailVerificationPage(),
        ),
      ),
      // In-app notification inbox — shared by every role (not under /admin or
      // /manager, so no role guard blocks it).
      GoRoute(
        path: RouteNames.notifications,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.profile,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ProfilePage(),
        ),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const EditProfilePage(),
        ),
      ),
      GoRoute(
        path: RouteNames.settings,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const SettingsPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ChangePasswordPage(),
        ),
      ),
    ],
  );
}

CustomTransitionPage<void> _fadeTransition(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

CustomTransitionPage<void> _slideTransition(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1.0, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6),
            ),
            child: child,
          ),
        );
      },
    );

/// True when [loc] is anywhere inside the admin area (`/admin` or `/admin/...`).
bool _isAdminArea(String loc) =>
    loc == RouteNames.adminDashboard ||
    loc.startsWith('${RouteNames.adminDashboard}/');

/// True when [loc] is anywhere inside the manager area (`/manager` or `/manager/...`).
bool _isManagerArea(String loc) =>
    loc == RouteNames.managerHome ||
    loc.startsWith('${RouteNames.managerHome}/');

/// True when [loc] is anywhere inside the Communications Center
/// (`/communications` or `/communications/...`) — admin + manager only.
bool _isCommunicationsArea(String loc) =>
    loc == RouteNames.communications ||
    loc.startsWith('${RouteNames.communications}/');

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(AuthCubit cubit) {
    cubit.stream.listen((_) => notifyListeners());
  }
}
