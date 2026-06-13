import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 50),
                  child: Text(
                    'Create\nAccount',
                    style: AppTypography.displayMedium.copyWith(
                      color: isDark ? AppColors.textPrimary : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 120),
                  child: const Text(
                    'Fill in the details below to get started.',
                    style: AppTypography.bodyLarge,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 180),
                  child: AppTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'John Doe',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your name' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 230),
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
                  delay: const Duration(milliseconds: 280),
                  child: AppTextField(
                    controller: _passwordController,
                    label: 'Password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 340),
                  beginOffset: const Offset(0, 16),
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final isLoading = state.maybeWhen(
                        loading: () => true,
                        orElse: () => false,
                      );
                      return AppButton(
                        label: 'Create Account',
                        isLoading: isLoading,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            context.read<AuthCubit>().registerWithEmail(
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

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 380),
                  child: Center(
                    child: Text(
                      'By creating an account, you agree to our\nTerms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption,
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
