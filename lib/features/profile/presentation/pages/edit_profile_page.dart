import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fbro/core/theme/app_colors.dart';
import 'package:fbro/core/theme/app_radius.dart';
import 'package:fbro/core/theme/app_spacing.dart';
import 'package:fbro/core/theme/app_typography.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_state.dart';
import 'package:fbro/features/auth/presentation/widgets/app_button.dart';
import 'package:fbro/features/auth/presentation/widgets/app_text_field.dart';
import 'package:fbro/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fbro/features/profile/presentation/cubit/profile_state.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late UserEntity _initialUser;

  @override
  void initState() {
    super.initState();
    _initialUser = context.read<AuthCubit>().state.maybeWhen(
          authenticated: (u) => u,
          orElse: () => const UserEntity(
            uid: '',
            email: '',
            authProvider: '',
          ),
        );
    _nameController.text = _initialUser.displayName ?? '';
    _photoUrlController.text = _initialUser.photoUrl ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit Profile', style: AppTypography.h3),
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          state.whenOrNull(
            updated: (user) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile updated successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
              context.pop();
            },
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
        builder: (context, state) {
          final isUpdating =
              state.maybeWhen(updating: () => true, orElse: () => false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Avatar preview
                  Center(
                    child: BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, authState) {
                        final user = authState.maybeWhen(
                          authenticated: (u) => u,
                          orElse: () => _initialUser,
                        );
                        final initials = user.displayName?.isNotEmpty == true
                            ? user.displayName![0].toUpperCase()
                            : user.email.isNotEmpty
                                ? user.email[0].toUpperCase()
                                : '?';
                        return Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: AppRadius.fullAll,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: AppTypography.h2
                                  .copyWith(color: AppColors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Text('Display Name', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _nameController,
                    label: 'Display Name',
                    hint: 'Your full name',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Display name cannot be empty';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text('Photo URL', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _photoUrlController,
                    label: 'Photo URL (optional)',
                    hint: 'https://example.com/photo.jpg',
                    prefixIcon: Icons.image_outlined,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  AppButton(
                    label: 'Save Changes',
                    isLoading: isUpdating,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final name = _nameController.text.trim();
                        final photo = _photoUrlController.text.trim();
                        context.read<ProfileCubit>().updateProfile(
                              uid: _initialUser.uid,
                              displayName: name != _initialUser.displayName
                                  ? name
                                  : null,
                              photoUrl: photo.isNotEmpty &&
                                      photo != _initialUser.photoUrl
                                  ? photo
                                  : null,
                            );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
