import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  Timer? _pollTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) context.read<AuthCubit>().checkEmailVerified();
    });
  }

  void _resend() {
    context.read<AuthCubit>().sendEmailVerification();
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            error: (msg) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final email = state.maybeWhen(
              awaitingEmailVerification: (u) => u.email,
              orElse: () => '',
            );
            final isLoading =
                state.maybeWhen(loading: () => true, orElse: () => false);

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 50),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.subtleGradient,
                          borderRadius: AppRadius.cardAll,
                          border: Border.all(
                            color: AppColors.primary.withAlpha(60),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.forward_to_inbox_outlined,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 120),
                      child: Text(
                        'Verify Your\nEmail',
                        style: AppTypography.displayMedium,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 180),
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.bodyLarge,
                          children: [
                            const TextSpan(
                                text: "We've sent a verification link to\n"),
                            TextSpan(
                              text: email,
                              style: AppTypography.label.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '\n\nOpen your email and tap the link to activate your account.',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 240),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: AppRadius.cardAll,
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary.withAlpha(180),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Waiting for verification…',
                              style: AppTypography.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 300),
                      beginOffset: const Offset(0, 16),
                      child: AppButton(
                        label: "I've Verified My Email",
                        isLoading: isLoading,
                        onPressed: () =>
                            context.read<AuthCubit>().checkEmailVerified(),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 360),
                      child: Center(
                        child: _resendCooldown > 0
                            ? Text(
                                'Resend in ${_resendCooldown}s',
                                style: AppTypography.body,
                              )
                            : GestureDetector(
                                onTap: _resend,
                                child: Text(
                                  "Didn't receive it? Resend email",
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 400),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => context.read<AuthCubit>().signOut(),
                          child: Text(
                            'Sign out',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
