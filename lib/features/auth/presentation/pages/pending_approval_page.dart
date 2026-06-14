import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/fbro_logo.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';

/// Holding screen shown to an authenticated account that has not yet been
/// approved (or has been deactivated). FBRO is an internal ops system: a new
/// account cannot use the app until a manager/admin approves it.
///
/// The screen polls [AuthCubit.refreshUser] so the moment a manager/admin
/// approves the account (`approvalStatus` → approved, `isActive` → true) the
/// router redirects the user straight into their role shell — no re-login.
class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) context.read<AuthCubit>().refreshUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthCubit, String>(
      (c) => c.state.maybeWhen(
        authenticated: (u) => u.email,
        orElse: () => '',
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              const FadeSlideTransition(
                delay: Duration(milliseconds: 50),
                child: FbroLogo(fontSize: 28),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 120),
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
                      Icons.hourglass_top_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 180),
                child: Text(
                  'Account Pending\nApproval',
                  style: AppTypography.displayMedium,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 240),
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.bodyLarge,
                    children: [
                      const TextSpan(
                        text: 'Your account has been created successfully.\n\n'
                            'It is waiting for approval by your manager or '
                            'administrator. ',
                      ),
                      if (email.isNotEmpty)
                        TextSpan(
                          text: '($email)\n\n',
                          style: AppTypography.label.copyWith(
                            color: AppColors.primary,
                          ),
                        )
                      else
                        const TextSpan(text: '\n'),
                      const TextSpan(
                        text:
                            "You'll be able to use the system as soon as your "
                            'account is activated.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 300),
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
                      Expanded(
                        child: Text(
                          'Waiting for approval…',
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 360),
                beginOffset: const Offset(0, 16),
                child: AppButton(
                  label: 'Check Approval Status',
                  onPressed: () => context.read<AuthCubit>().refreshUser(),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 420),
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
      ),
    );
  }
}
