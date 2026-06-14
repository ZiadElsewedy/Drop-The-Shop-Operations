import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/pages/splash_page.dart';
import 'package:fbro/features/auth/presentation/pages/welcome_page.dart';
import 'package:fbro/features/auth/presentation/pages/login_page.dart';
import 'package:fbro/features/auth/presentation/pages/register_page.dart';
import 'package:fbro/features/auth/presentation/pages/phone_otp_page.dart';
import 'package:fbro/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:fbro/features/auth/presentation/pages/email_verification_page.dart';
import 'package:fbro/features/admin/presentation/pages/admin_shell.dart';
import 'package:fbro/features/manager/presentation/pages/manager_shell.dart';
import 'package:fbro/features/employee/presentation/pages/employee_shell.dart';
import 'package:fbro/features/profile/presentation/pages/profile_page.dart';
import 'package:fbro/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:fbro/features/settings/presentation/pages/settings_page.dart';
import 'package:fbro/features/settings/presentation/pages/change_password_page.dart';
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

      final isOnAuthFlow = loc == RouteNames.welcome ||
          loc == RouteNames.login ||
          loc == RouteNames.register ||
          loc == RouteNames.phone ||
          loc == RouteNames.forgotPassword;

      if (isAwaitingVerification && loc != RouteNames.emailVerification) {
        // go_router redirect doesn't support extra — navigation is handled by
        // the BlocListener in each auth page and SplashPage instead.
        return RouteNames.emailVerification;
      }

      if (isAuthenticated) {
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
        if (loc == RouteNames.home && !user.role.isEmployee) {
          return roleHome;
        }

        // Leaving the auth flow / verification screen → role home.
        if (isOnAuthFlow || loc == RouteNames.emailVerification) {
          return roleHome;
        }

        return null;
      }

      if (!isAwaitingVerification && !isOnAuthFlow) {
        if (loc != RouteNames.splash) return RouteNames.welcome;
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
        path: RouteNames.welcome,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const WelcomePage(),
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

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(AuthCubit cubit) {
    cubit.stream.listen((_) => notifyListeners());
  }
}
