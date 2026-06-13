import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<UserModel> registerWithEmail({required String email, required String password});
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(UserModel user)? onAutoVerified,
  });
  Future<UserModel> signInWithOtp({required String verificationId, required String smsCode});
  Future<void> signOut();
  UserModel? get currentUser;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  AuthRemoteDataSourceImpl(this._auth);

  String _resolveProvider(User user) {
    if (user.providerData.isEmpty) return 'unknown';
    final id = user.providerData.first.providerId;
    if (id == 'password') return 'email';
    if (id == 'phone') return 'phone';
    return id;
  }

  @override
  Stream<UserModel?> get authStateChanges => _auth
      .authStateChanges()
      .map((u) => u == null
          ? null
          : UserModel.fromFirebaseUser(u, authProvider: _resolveProvider(u)));

  @override
  UserModel? get currentUser {
    final u = _auth.currentUser;
    return u == null
        ? null
        : UserModel.fromFirebaseUser(u, authProvider: _resolveProvider(u));
  }

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      return UserModel.fromFirebaseUser(user, authProvider: _resolveProvider(user));
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign in failed');
    }
  }

  @override
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      return UserModel.fromFirebaseUser(user, authProvider: _resolveProvider(user));
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Registration failed');
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(UserModel user)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          if (result.user != null) {
            final u = result.user!;
            onAutoVerified?.call(
                UserModel.fromFirebaseUser(u, authProvider: _resolveProvider(u)));
          }
        } on FirebaseAuthException catch (e) {
          onFailed(e.message ?? 'Auto-verification failed');
        }
      },
      verificationFailed: (e) => onFailed(e.message ?? 'Verification failed'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<UserModel> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      final u = result.user!;
      return UserModel.fromFirebaseUser(u, authProvider: _resolveProvider(u));
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'OTP verification failed');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
