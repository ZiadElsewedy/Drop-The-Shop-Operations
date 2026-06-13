import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbro/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fbro/features/auth/data/datasources/user_remote_datasource.dart';
import 'package:fbro/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:fbro/features/auth/domain/usecases/register_with_email.dart';
import 'package:fbro/features/auth/domain/usecases/verify_phone_number.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_otp.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:fbro/features/auth/domain/usecases/sign_out.dart';
import 'package:fbro/features/auth/domain/usecases/save_user.dart';
import 'package:fbro/features/auth/domain/usecases/get_user.dart';
import 'package:fbro/features/auth/domain/usecases/forgot_password.dart';
import 'package:fbro/features/auth/domain/usecases/send_email_verification.dart';
import 'package:fbro/features/auth/domain/usecases/check_email_verified.dart';
import 'package:fbro/features/auth/domain/usecases/change_password.dart';
import 'package:fbro/features/auth/domain/usecases/delete_account.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:fbro/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:fbro/features/profile/domain/repositories/profile_repository.dart';
import 'package:fbro/features/profile/domain/usecases/get_profile.dart';
import 'package:fbro/features/profile/domain/usecases/update_profile.dart';
import 'package:fbro/features/profile/presentation/cubit/profile_cubit.dart';

class AppDependencies {
  AppDependencies._();

  static late final AuthCubit authCubit;
  static late final ProfileCubit profileCubit;

  static void init() {
    final authRemoteDataSource = AuthRemoteDataSourceImpl(FirebaseAuth.instance);
    final userRemoteDataSource = UserRemoteDataSourceImpl(FirebaseFirestore.instance);
    final profileRemoteDataSource = ProfileRemoteDataSourceImpl(FirebaseFirestore.instance);

    final AuthRepository authRepository =
        AuthRepositoryImpl(authRemoteDataSource, userRemoteDataSource);

    final ProfileRepository profileRepository =
        ProfileRepositoryImpl(profileRemoteDataSource, authRemoteDataSource);

    authCubit = AuthCubit(
      repository: authRepository,
      signInWithEmail: SignInWithEmail(authRepository),
      registerWithEmail: RegisterWithEmail(authRepository),
      verifyPhoneNumber: VerifyPhoneNumber(authRepository),
      signInWithOtp: SignInWithOtp(authRepository),
      signInWithGoogle: SignInWithGoogle(authRepository),
      signOut: SignOut(authRepository),
      saveUser: SaveUser(authRepository),
      getUser: GetUser(authRepository),
      forgotPassword: ForgotPassword(authRepository),
      sendEmailVerification: SendEmailVerification(authRepository),
      checkEmailVerified: CheckEmailVerified(authRepository),
      changePassword: ChangePassword(authRepository),
      deleteAccount: DeleteAccount(authRepository),
    );

    profileCubit = ProfileCubit(
      getProfile: GetProfile(profileRepository),
      updateProfile: UpdateProfile(profileRepository),
    );
  }
}
