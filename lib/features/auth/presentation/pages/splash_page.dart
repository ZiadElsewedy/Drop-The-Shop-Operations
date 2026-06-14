import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/di/injection.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/fbro_logo.dart';

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
      initial: () => context.go(RouteNames.welcome),
      loading: (_) => context.go(RouteNames.welcome),
      authenticated: (user) => context.go(RouteNames.homeForRole(user.role)),
      unauthenticated: () => context.go(RouteNames.welcome),
      otpSent: (_) => context.go(RouteNames.welcome),
      awaitingEmailVerification: (_) => context.go(RouteNames.emailVerification),
      passwordResetSent: () => context.go(RouteNames.welcome),
      passwordChanged: () => context.go(RouteNames.home),
      error: (_) => context.go(RouteNames.welcome),
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
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo dot
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: const FbroLogo(fontSize: 40),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  'Loading...',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
