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
import 'package:fbro/features/auth/domain/usecases/sign_out.dart';
import 'package:fbro/features/auth/domain/usecases/save_user.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';

class AppDependencies {
  AppDependencies._();

  static late final AuthCubit authCubit;

  static void init() {
    final remoteDataSource = AuthRemoteDataSourceImpl(FirebaseAuth.instance);
    final userRemoteDataSource =
        UserRemoteDataSourceImpl(FirebaseFirestore.instance);

    final AuthRepository authRepository =
        AuthRepositoryImpl(remoteDataSource, userRemoteDataSource);

    authCubit = AuthCubit(
      repository: authRepository,
      signInWithEmail: SignInWithEmail(authRepository),
      registerWithEmail: RegisterWithEmail(authRepository),
      verifyPhoneNumber: VerifyPhoneNumber(authRepository),
      signInWithOtp: SignInWithOtp(authRepository),
      signOut: SignOut(authRepository),
      saveUser: SaveUser(authRepository),
    );
  }
}
