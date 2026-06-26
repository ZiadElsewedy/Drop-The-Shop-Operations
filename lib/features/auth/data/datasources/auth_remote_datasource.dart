import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

/// Firebase Auth access. DROP is **admin-provisioned** — there is no public
/// registration, Google sign-in, or phone/OTP path here. Accounts are created
/// server-side by the `createUserAccount` Cloud Function; clients only sign in
/// with email/password, reset/change their password, and keep the Auth profile
/// (display name / photo) in sync with Firestore.
abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;

  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);
  Future<void> updateDisplayName(String displayName);
  Future<void> updatePhotoUrl(String photoUrl);
  Future<void> changePassword({required String currentPassword, required String newPassword});
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
      throw AuthException(_resolveSignInError(e.code, e.message));
    }
  }

  String _resolveSignInError(String code, String? message) {
    switch (code) {
      // Modern Firebase collapses wrong-password / user-not-found into the
      // generic invalid-credential for email-enumeration protection.
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return message ?? 'Sign in failed. Please try again.';
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
}
