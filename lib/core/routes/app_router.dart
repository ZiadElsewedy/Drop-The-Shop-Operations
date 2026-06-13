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
import 'package:fbro/features/home/presentation/pages/home_page.dart';
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

      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );

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

      if (isAuthenticated && isOnAuthFlow) return RouteNames.home;
      if (isAuthenticated && loc == RouteNames.emailVerification) {
        return RouteNames.home;
      }

      if (!isAuthenticated && !isAwaitingVerification && !isOnAuthFlow) {
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
          const HomePage(),
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

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(AuthCubit cubit) {
    cubit.stream.listen((_) => notifyListeners());
  }
}
