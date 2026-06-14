import 'package:fbro/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  UserEntity? get currentUser;

  Future<UserEntity> signInWithEmail({required String email, required String password});
  Future<UserEntity> registerWithEmail({required String email, required String password});
  Future<UserEntity> signInWithGoogle();
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(UserEntity user)? onAutoVerified,
  });
  Future<UserEntity> signInWithOtp({required String verificationId, required String smsCode});
  Future<void> signOut();

  Future<void> saveUser(UserEntity user);
  Future<UserEntity?> getUser(String uid);
  Future<List<UserEntity>> getUsersByBranch(String branchId);
  Future<UserEntity> reloadUser();

  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> updateDisplayName(String displayName);
  Future<void> updatePhotoUrl(String photoUrl);
  Future<void> changePassword({required String currentPassword, required String newPassword});
  Future<void> deleteAccount({required String? currentPassword, required String? accessToken});
}
