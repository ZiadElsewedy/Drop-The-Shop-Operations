import 'package:fbro/core/enums/user_role.dart';

class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String phone = '/phone';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';

  /// Holding screen for authenticated-but-not-yet-approved accounts.
  static const String pendingApproval = '/pending-approval';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String changePassword = '/settings/change-password';

  // ─── Role shells (Phase 1) ──────────────────────────────────
  // The employee role uses [home] ('/') as its landing.
  static const String adminDashboard = '/admin';
  static const String managerHome = '/manager';

  // ─── Shifts (Phase 2) ───────────────────────────────────────
  // Admin/manager shift screens live under their role area so the existing
  // `_isAdminArea` / `_isManagerArea` guards cover them; the employee shift
  // screen is self-scoped (shows only the caller's own shift).
  static const String adminShifts = '/admin/shifts';
  static const String managerShifts = '/manager/shifts';
  static const String myShift = '/my-shift';

  // ─── Tasks (Phase 3) ────────────────────────────────────────
  // Admin/manager task screens live under their role area so the existing
  // `_isAdminArea` / `_isManagerArea` guards cover them; the employee task
  // screen is self-scoped (shows only the caller's own tasks).
  static const String adminTasks = '/admin/tasks';
  static const String managerTasks = '/manager/tasks';
  static const String myTasks = '/my-tasks';

  // ─── Admin module (Phase 5) ─────────────────────────────────
  // All under the admin area, so the existing `_isAdminArea` guard covers them.
  static const String adminBranches = '/admin/branches';
  static const String adminManagers = '/admin/managers';
  static const String adminEmployees = '/admin/employees';
  static const String adminApprovals = '/admin/approvals';

  /// The landing route for a given role, used by the router redirect and the
  /// splash screen to dispatch each user to their own shell.
  static String homeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminDashboard;
      case UserRole.manager:
        return managerHome;
      case UserRole.employee:
        return home;
    }
  }

  /// The shift screen for a given role (admin: all branches, manager: own
  /// branch, employee: own shift). Used by the shared role chrome.
  static String shiftsForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminShifts;
      case UserRole.manager:
        return managerShifts;
      case UserRole.employee:
        return myShift;
    }
  }

  /// The task screen for a given role (admin: all branches, manager: own branch,
  /// employee: own tasks). Used by the shared role chrome.
  static String tasksForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminTasks;
      case UserRole.manager:
        return managerTasks;
      case UserRole.employee:
        return myTasks;
    }
  }
}
