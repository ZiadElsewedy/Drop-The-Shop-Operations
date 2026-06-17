import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/auth/presentation/widgets/otp_input.dart';

class PhoneOtpPage extends StatefulWidget {
  const PhoneOtpPage({super.key});

  @override
  State<PhoneOtpPage> createState() => _PhoneOtpPageState();
}

class _PhoneOtpPageState extends State<PhoneOtpPage> {
  final _phoneController = TextEditingController();
  String? _verificationId;
  String _otp = '';
  int _resendCount = 0;

  // Resend timer
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            otpSent: (id) {
              setState(() => _verificationId = id);
              _startResendTimer();
            },
            error: (msg) => AppSnackbar.error(context, msg),
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
                      .animate(anim),
              child: child,
            ),
          ),
          child: _verificationId == null
              ? _PhoneStep(
                  key: const ValueKey('phone'),
                  controller: _phoneController,
                  isDark: isDark,
                )
              : _OtpStep(
                  key: const ValueKey('otp'),
                  phone: _phoneController.text,
                  secondsLeft: _secondsLeft,
                  timerLabel: _timerLabel,
                  verificationId: _verificationId!,
                  resendCount: _resendCount,
                  onOtpChanged: (v) => setState(() => _otp = v),
                  onResend: () {
                    setState(() {
                      _otp = '';
                      _resendCount++;
                    });
                    context
                        .read<AuthCubit>()
                        .verifyPhone('+20${_phoneController.text.trim()}');
                  },
                  otp: _otp,
                  isDark: isDark,
                ),
        ),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _PhoneStep({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 50),
            child: Text(
              'Your Phone\nNumber',
              style: AppTypography.displayMedium.copyWith(
                color: isDark ? AppColors.textPrimary : AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 120),
            child: const Text(
              "We'll send a verification code to this number.",
              style: AppTypography.bodyLarge,
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Country + phone
          FadeSlideTransition(
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                // Country picker stub
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🇪🇬', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        '+20',
                        style: AppTypography.label.copyWith(
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: controller,
                    label: 'Phone Number',
                    hint: '100 000 0000',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 280),
            beginOffset: const Offset(0, 16),
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final action =
                    state.maybeWhen(loading: (a) => a, orElse: () => null);
                return AppButton(
                  label: 'Continue',
                  isLoading: action == AuthAction.phoneVerify,
                  onPressed: action != null
                      ? null
                      : () {
                          final digits = controller.text.trim();
                          if (digits.isEmpty) return;
                          // Combine the hardcoded country code with the typed
                          // number in E.164 format required by Firebase
                          // (+20XXXXXXXXXX).
                          context.read<AuthCubit>().verifyPhone('+20$digits');
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpStep extends StatelessWidget {
  final String phone;
  final int secondsLeft;
  final String timerLabel;
  final String verificationId;
  final String otp;
  final int resendCount;
  final void Function(String) onOtpChanged;
  final VoidCallback onResend;
  final bool isDark;

  const _OtpStep({
    super.key,
    required this.phone,
    required this.secondsLeft,
    required this.timerLabel,
    required this.verificationId,
    required this.otp,
    required this.resendCount,
    required this.onOtpChanged,
    required this.onResend,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 50),
            child: Text(
              'Enter the\nCode',
              style: AppTypography.displayMedium.copyWith(
                color: isDark ? AppColors.textPrimary : AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 120),
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodyLarge,
                children: [
                  const TextSpan(text: 'Sent to '),
                  TextSpan(
                    text: phone,
                    style: AppTypography.bodyLarge.copyWith(
                      color: isDark ? AppColors.textPrimary : AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 200),
            child: OtpInput(
              key: ValueKey('otp_input_$resendCount'),
              onCompleted: onOtpChanged,
              onChanged: onOtpChanged,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Resend timer
          FadeSlideTransition(
            delay: const Duration(milliseconds: 260),
            child: Center(
              child: secondsLeft > 0
                  ? Text(
                      'Resend code in $timerLabel',
                      style: AppTypography.body,
                    )
                  : GestureDetector(
                      onTap: onResend,
                      child: Text(
                        'Resend code',
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 320),
            beginOffset: const Offset(0, 16),
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final action =
                    state.maybeWhen(loading: (a) => a, orElse: () => null);
                final canVerify = otp.length == 6 && action == null;
                return AppButton(
                  label: 'Verify',
                  isLoading: action == AuthAction.otpVerify,
                  onPressed: canVerify
                      ? () => context
                          .read<AuthCubit>()
                          .verifyOtp(verificationId, otp)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
