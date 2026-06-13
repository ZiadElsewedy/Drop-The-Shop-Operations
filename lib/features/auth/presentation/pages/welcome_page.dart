import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Subtle background glow
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlpha(30),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gradientEnd.withAlpha(20),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxxl),

                  // Logo mark
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 100),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'F',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Headline
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 200),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.display.copyWith(
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textDark,
                        ),
                        children: [
                          const TextSpan(text: 'Welcome to\nthe future of\n'),
                          TextSpan(
                            text: 'shopping.',
                            style: TextStyle(
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    AppColors.gradientStart,
                                    AppColors.gradientEnd,
                                  ],
                                ).createShader(
                                  const Rect.fromLTWH(0, 0, 280, 60),
                                ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      'Discover, shop, and track everything\nin one beautiful place.',
                      style: AppTypography.bodyLarge,
                    ),
                  ),

                  const Spacer(),

                  // CTA buttons
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 450),
                    beginOffset: const Offset(0, 16),
                    child: AppButton(
                      label: 'Get Started',
                      onPressed: () => context.push(RouteNames.register),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 520),
                    beginOffset: const Offset(0, 16),
                    child: AppButton.ghost(
                      label: 'Already have an account?  Sign In',
                      onPressed: () => context.push(RouteNames.login),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
