import 'package:fbro/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserEntity> registerWithEmail({
    required String email,
    required String password,
  });

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(UserEntity user)? onAutoVerified,
  });

  Future<UserEntity> signInWithOtp({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();

  Future<void> saveUser(UserEntity user);

  UserEntity? get currentUser;
}
