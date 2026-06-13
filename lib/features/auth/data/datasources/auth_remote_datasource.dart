import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;

  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<UserModel> registerWithEmail({required String email, required String password});
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(UserModel user)? onAutoVerified,
  });
  Future<UserModel> signInWithOtp({required String verificationId, required String smsCode});
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<UserModel> reloadUser();
  Future<void> updateDisplayName(String displayName);
  Future<void> updatePhotoUrl(String photoUrl);
  Future<void> changePassword({required String currentPassword, required String newPassword});
  Future<void> deleteAccount({required String? currentPassword, required String? accessToken});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSourceImpl(this._auth, {GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn();

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
    try {
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
          } catch (_) {
            onFailed('Auto-verification failed. Please try again.');
          }
        },
        verificationFailed: (e) {
          final message = _resolvePhoneError(e.code, e.message);
          onFailed(message);
        },
        codeSent: (verificationId, _) => onCodeSent(verificationId),
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolvePhoneError(e.code, e.message));
    } catch (e) {
      throw AuthException('Phone verification failed. Please try again.');
    }
  }

  String _resolvePhoneError(String code, String? message) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number is not valid. Please include the country code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before trying again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled. Contact support.';
      default:
        return message ?? 'Verification failed. Please try again.';
    }
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
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw const AuthException('Google sign-in was cancelled.');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final u = result.user!;
      return UserModel.fromFirebaseUser(u, authProvider: 'google');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolveGoogleError(e.code, e.message));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Google sign-in failed. Please try again.');
    }
  }

  String _resolveGoogleError(String code, String? message) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return message ?? 'Google sign-in failed.';
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolvePasswordResetError(e.code, e.message));
    }
  }

  String _resolvePasswordResetError(String code, String? message) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'too-many-requests':
        return 'Too many requests. Please wait before trying again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return message ?? 'Failed to send reset email.';
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Failed to send verification email.');
    }
  }

  @override
  Future<UserModel> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    await user.reload();
    final refreshed = _auth.currentUser!;
    return UserModel.fromFirebaseUser(refreshed, authProvider: _resolveProvider(refreshed));
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      await user.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Failed to update display name.');
    }
  }

  @override
  Future<void> updatePhotoUrl(String photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      await user.updatePhotoURL(photoUrl);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Failed to update photo.');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolveChangePasswordError(e.code, e.message));
    }
  }

  String _resolveChangePasswordError(String code, String? message) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Your current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again before changing your password.';
      default:
        return message ?? 'Failed to change password.';
    }
  }

  @override
  Future<void> deleteAccount({
    required String? currentPassword,
    required String? accessToken,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      if (currentPassword != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      } else if (accessToken != null) {
        final credential = GoogleAuthProvider.credential(accessToken: accessToken);
        await user.reauthenticateWithCredential(credential);
      }
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolveDeleteError(e.code, e.message));
    }
  }

  String _resolveDeleteError(String code, String? message) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Account was not deleted.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again before deleting your account.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return message ?? 'Failed to delete account.';
    }
  }
}
