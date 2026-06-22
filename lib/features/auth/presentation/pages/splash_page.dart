import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/di/injection.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/drop_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _initSession();
  }

  Future<void> _initSession() async {
    await Future.wait([
      AppDependencies.authCubit.restoreSession(),
      Future.delayed(const Duration(milliseconds: 2400)),
    ]);
    if (!mounted) return;

    AppDependencies.authCubit.state.when(
      initial: () => context.go(RouteNames.login),
      loading: (_) => context.go(RouteNames.login),
      authenticated: (user) => context.go(
        user.hasAppAccess
            ? RouteNames.homeForRole(user.role)
            : RouteNames.pendingApproval,
      ),
      unauthenticated: () => context.go(RouteNames.login),
      otpSent: (_) => context.go(RouteNames.login),
      awaitingEmailVerification: (_) => context.go(RouteNames.emailVerification),
      passwordResetSent: () => context.go(RouteNames.login),
      passwordChanged: () => context.go(RouteNames.login),
      error: (_) => context.go(RouteNames.login),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Soft indigo glow bloom behind the brand lockup.
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: const DropLogo(height: 92),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'THE SHOP',
                          style: AppTypography.labelLarge.copyWith(
                            letterSpacing: 6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Operations Management System',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Loading bar + version pinned to the bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          color: AppColors.primary,
                          backgroundColor: AppColors.darkSurfaceElevated,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Version 1.0.0',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
