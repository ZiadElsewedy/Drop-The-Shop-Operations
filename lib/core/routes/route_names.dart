import 'package:fbro/core/enums/user_role.dart';

class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String phone = '/phone';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String changePassword = '/settings/change-password';

  // ─── Role shells (Phase 1) ──────────────────────────────────
  // The employee role uses [home] ('/') as its landing.
  static const String adminDashboard = '/admin';
  static const String managerHome = '/manager';

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
}
