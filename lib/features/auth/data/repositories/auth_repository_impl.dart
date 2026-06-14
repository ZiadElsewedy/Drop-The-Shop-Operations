import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fbro/features/auth/data/datasources/user_remote_datasource.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final UserRemoteDataSource _userRemote;

  AuthRepositoryImpl(this._remote, this._userRemote);

  @override
  Stream<UserEntity?> get authStateChanges =>
      _remote.authStateChanges.map((m) => m?.toEntity());

  @override
  UserEntity? get currentUser => _remote.currentUser?.toEntity();

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _remote.signInWithEmail(email: email, password: password);
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<UserEntity> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _remote.registerWithEmail(email: email, password: password);
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    try {
      final model = await _remote.signInWithGoogle();
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(UserEntity user)? onAutoVerified,
  }) async {
    try {
      await _remote.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: onCodeSent,
        onFailed: onFailed,
        onAutoVerified:
            onAutoVerified != null ? (m) => onAutoVerified(m.toEntity()) : null,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<UserEntity> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final model = await _remote.signInWithOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> signOut() => _remote.signOut();

  @override
  Future<UserEntity?> getUser(String uid) async {
    final model = await _userRemote.getUser(uid);
    return model?.toEntity();
  }

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async {
    try {
      final models = await _userRemote.getUsersByBranch(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<UserEntity> reloadUser() async {
    try {
      final model = await _remote.reloadUser();
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> saveUser(UserEntity user) async {
    await _userRemote.saveUser(UserModel.fromEntity(user));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _remote.sendPasswordResetEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _remote.sendEmailVerification();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _remote.updateDisplayName(displayName);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> updatePhotoUrl(String photoUrl) async {
    try {
      await _remote.updatePhotoUrl(photoUrl);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> deleteAccount({
    required String? currentPassword,
    required String? accessToken,
  }) async {
    try {
      await _remote.deleteAccount(
        currentPassword: currentPassword,
        accessToken: accessToken,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
