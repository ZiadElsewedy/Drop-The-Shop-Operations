import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/drop_logo.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';

/// Holding screen shown to an authenticated account that has not yet been
/// approved (or has been deactivated). DROP is an internal ops system: a new
/// account cannot use the app until a manager/admin approves it.
///
/// The screen live-watches the user's document via [AuthCubit.watchCurrentUser]
/// so the moment a manager/admin approves the account (`approvalStatus` →
/// approved, `isActive` → true) the router redirects the user straight into
/// their role shell — in real time, no polling and no re-login.
class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  // Captured in initState so dispose never touches `context`.
  late final AuthCubit _auth = context.read<AuthCubit>();

  @override
  void initState() {
    super.initState();
    _auth.watchCurrentUser();
  }

  @override
  void dispose() {
    _auth.stopWatchingUser();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              const Center(
                child: FadeSlideTransition(
                  delay: Duration(milliseconds: 40),
                  child: DropLogo(height: 40),
                ),
              ),

              const Spacer(),

              const FadeSlideTransition(
                delay: Duration(milliseconds: 120),
                child: Center(child: _PulsingClock()),
              ),

              const SizedBox(height: AppSpacing.xxl),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Pending Approval',
                  textAlign: TextAlign.center,
                  style: AppTypography.h1,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 260),
                child: Text(
                  'Your account is under review.\n'
                  'You will get access once an admin approves your account.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              const FadeSlideTransition(
                delay: Duration(milliseconds: 320),
                child: _WhatHappensNext(),
              ),

              const Spacer(),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 400),
                child: Center(
                  child: TextButton(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    child: Text(
                      'Log out',
                      style: AppTypography.label
                          .copyWith(color: AppColors.textSecondary),
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

/// The glowing indigo clock — the signature element of the pending screen. A
/// gradient disc with a clock glyph, wrapped by a faint ring and a slow,
/// breathing indigo halo so the screen reads as "live / waiting".
class _PulsingClock extends StatefulWidget {
  const _PulsingClock();

  @override
  State<_PulsingClock> createState() => _PulsingClockState();
}

class _PulsingClockState extends State<_PulsingClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.20 + 0.20 * t),
                blurRadius: 28 + 18 * t,
                spreadRadius: 2 + 4 * t,
              ),
            ],
          ),
          child: Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppColors.onPrimary,
              size: 38,
            ),
          ),
        );
      },
    );
  }
}

/// The "What happens next?" card — the three review steps, matching the design.
class _WhatHappensNext extends StatelessWidget {
  const _WhatHappensNext();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.xxlAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happens next?', style: AppTypography.label),
          const SizedBox(height: AppSpacing.lg),
          _step(1, 'Admin will review your details'),
          _step(2, 'You will get a notification'),
          _step(3, 'You can start using the app', last: true),
        ],
      ),
    );
  }

  Widget _step(int n, String label, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySurface,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$n',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.body)),
        ],
      ),
    );
  }
}
