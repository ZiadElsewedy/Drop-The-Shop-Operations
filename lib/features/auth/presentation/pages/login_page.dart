import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/routes/route_names.dart';

import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/core/widgets/app_snackbar.dart';
import 'package:fbro/core/widgets/drop_logo.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/auth/presentation/widgets/app_password_field.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        // Login is the unauthenticated landing screen, so it usually has nothing
        // to pop back to; only show a back button when it was pushed onto a stack.
        leading: context.canPop() ? const BackButton() : null,
        backgroundColor: Colors.transparent,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            error: (msg) => AppSnackbar.error(context, msg),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                const FadeSlideTransition(
                  delay: Duration(milliseconds: 30),
                  child: DropLogo(height: 52),
                ),

                const SizedBox(height: AppSpacing.xxl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 50),
                  child: Text(
                    'Welcome Back',
                    style: AppTypography.displayMedium.copyWith(
                      color: isDark ? AppColors.textPrimary : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 120),
                  child: const Text(
                    'Sign in to continue',
                    style: AppTypography.bodyLarge,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 180),
                  child: AppTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'example@gmail.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your email' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 240),
                  child: AppPasswordField(
                    controller: _passwordController,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 280),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(RouteNames.forgotPassword),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(
                        'Forgot password?',
                        style: AppTypography.label
                            .copyWith(color: AppColors.primary),
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
                      final action = state.maybeWhen(
                        loading: (a) => a,
                        orElse: () => null,
                      );
                      final busy = action != null;
                      return AppButton(
                        label: 'Sign In',
                        isLoading: action == AuthAction.emailSignIn,
                        onPressed: busy
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthCubit>().signInWithEmail(
                                        _emailController.text.trim(),
                                        _passwordController.text,
                                      );
                                }
                              },
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Divider OR
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 380),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: Text(
                          'OR',
                          style: AppTypography.caption.copyWith(
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 420),
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final action = state.maybeWhen(
                        loading: (a) => a,
                        orElse: () => null,
                      );
                      final busy = action != null;
                      final googleLoading = action == AuthAction.google;
                      return AppButton.secondary(
                        label: 'Continue with Google',
                        isLoading: googleLoading,
                        icon: googleLoading
                            ? null
                            : const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 24,
                                color: AppColors.primary,
                              ),
                        onPressed: busy
                            ? null
                            : () => context.read<AuthCubit>().signInWithGoogle(),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 460),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?  ",
                        style: AppTypography.body,
                      ),
                      GestureDetector(
                        onTap: () => context.push(RouteNames.register),
                        child: Text(
                          'Create one',
                          style: AppTypography.label.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 490),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => context.push(RouteNames.phone),
                      child: Text(
                        'Sign in with Phone Number',
                        style: AppTypography.label
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
