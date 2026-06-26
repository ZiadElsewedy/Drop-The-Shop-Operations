import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';

import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/drop_auth_mark.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/auth/presentation/widgets/app_password_field.dart';

/// The DROP sign-in screen. DROP is **admin-provisioned**: there is no public
/// registration, Google sign-in, or phone/OTP — only email + password, plus a
/// Forgot Password path. Premium, strictly monochrome (white accent, no indigo).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      // Soft monochrome background wash behind the auth card.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkSurface, AppColors.darkBg],
          ),
        ),
        child: SafeArea(
          child: BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              state.whenOrNull(
                error: (msg) => AppSnackbar.error(context, msg),
              );
            },
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxxl),

                    // Centered brand lockup.
                    const FadeSlideTransition(
                      delay: Duration(milliseconds: 30),
                      child: Center(child: DropAuthMark()),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: AppTypography.displayMedium.copyWith(
                          color:
                              isDark ? AppColors.textPrimary : AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 140),
                      child: const Text(
                        'Sign in to your DROP account',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 200),
                      child: AppTextField(
                        controller: _emailController,
                        label: 'Email address',
                        hint: 'you@company.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter your email' : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 250),
                      child: AppPasswordField(
                        controller: _passwordController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (v) =>
                            v == null || v.length < 6 ? 'Min 6 characters' : null,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 290),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push(RouteNames.forgotPassword),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: Text(
                            'Forgot password?',
                            style: AppTypography.label
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 340),
                      beginOffset: const Offset(0, 16),
                      child: BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final busy = state.maybeWhen(
                              loading: (_) => true, orElse: () => false);
                          return AppButton(
                            label: 'Sign in',
                            isLoading: busy,
                            onPressed: busy ? null : _submit,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // No registration affordance — accounts are admin-created.
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 400),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Accounts are created by your administrator.',
                              style: AppTypography.caption,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
