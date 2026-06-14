import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
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
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  final SignInWithEmail _signInWithEmail;
  final RegisterWithEmail _registerWithEmail;
  final VerifyPhoneNumber _verifyPhoneNumber;
  final SignInWithOtp _signInWithOtp;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;
  final SaveUser _saveUser;
  final GetUser _getUser;
  final ForgotPassword _forgotPassword;
  final SendEmailVerification _sendEmailVerification;
  final CheckEmailVerified _checkEmailVerified;
  final ChangePassword _changePassword;
  final DeleteAccount _deleteAccount;

  StreamSubscription? _authSub;

  /// True while any auth action is in flight. Used to reject duplicate taps
  /// and concurrent requests (e.g. tapping Sign In then Google rapidly).
  bool get _busy => state.maybeWhen(loading: (_) => true, orElse: () => false);

  AuthCubit({
    required this._repository,
    required SignInWithEmail signInWithEmail,
    required this._registerWithEmail,
    required this._verifyPhoneNumber,
    required this._signInWithOtp,
    required this._signInWithGoogle,
    required this._signOut,
    required this._saveUser,
    required this._getUser,
    required this._forgotPassword,
    required this._sendEmailVerification,
    required this._checkEmailVerified,
    required this._changePassword,
    required this._deleteAccount,
  })  : _signInWithEmail = signInWithEmail,
        super(const AuthState.initial());

  /// Called once from SplashPage on cold start.
  Future<void> restoreSession() async {
    final firebaseUser = _repository.currentUser;
    if (firebaseUser == null) {
      emit(const AuthState.unauthenticated());
    } else {
      try {
        final firestoreUser = await _getUser(firebaseUser.uid);
        final user = firestoreUser ?? firebaseUser;
        if (user.authProvider == 'email' && !user.isEmailVerified) {
          emit(AuthState.awaitingEmailVerification(user));
        } else {
          emit(AuthState.authenticated(user));
        }
      } catch (_) {
        emit(AuthState.authenticated(firebaseUser));
      }
    }
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _repository.authStateChanges.listen((user) {
      if (user == null) {
        emit(const AuthState.unauthenticated());
      }
      // Positive auth events are handled explicitly per action to avoid
      // overwriting richer states (e.g. awaitingEmailVerification).
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.emailSignIn));
    try {
      final user = await _signInWithEmail(email: email, password: password);
      if (!user.isEmailVerified) {
        emit(AuthState.awaitingEmailVerification(user));
      } else {
        emit(AuthState.authenticated(user));
      }
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.register));
    try {
      var user = await _registerWithEmail(email: email, password: password);
      if (displayName != null && displayName.trim().isNotEmpty) {
        await _repository.updateDisplayName(displayName.trim());
        user = await _repository.reloadUser();
      }
      await _saveUser(user);
      await _sendEmailVerification();
      emit(AuthState.awaitingEmailVerification(user));
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> signInWithGoogle() async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.google));
    try {
      final user = await _signInWithGoogle();
      await _saveUser(user);
      emit(AuthState.authenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> verifyPhone(String phoneNumber) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.phoneVerify));
    try {
      await _verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) => emit(AuthState.otpSent(verificationId)),
        onFailed: (error) => emit(AuthState.error(error)),
        onAutoVerified: (user) => emit(AuthState.authenticated(user)),
      );
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    } catch (_) {
      emit(const AuthState.error('Phone verification failed. Please try again.'));
    }
  }

  Future<void> verifyOtp(String verificationId, String smsCode) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.otpVerify));
    try {
      final user = await _signInWithOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _saveUser(user);
      emit(AuthState.authenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> forgotPassword(String email) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.forgotPassword));
    try {
      await _forgotPassword(email);
      emit(const AuthState.passwordResetSent());
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _sendEmailVerification();
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> checkEmailVerified() async {
    try {
      final user = await _checkEmailVerified();
      if (user.isEmailVerified) {
        await _saveUser(user);
        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.awaitingEmailVerification(user));
      }
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.changePassword));
    try {
      await _changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      emit(const AuthState.passwordChanged());
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> deleteAccount({
    String? currentPassword,
    String? accessToken,
  }) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.deleteAccount));
    try {
      // Note: deleting the Firestore user document must happen *before* the
      // Firebase account is removed — once the account is gone the user is
      // signed out and security rules would reject the write. Proper cleanup
      // of the document belongs in a Cloud Function (auth.user().onDelete);
      // here we simply remove the auth account.
      await _deleteAccount(
        currentPassword: currentPassword,
        accessToken: accessToken,
      );
      emit(const AuthState.unauthenticated());
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> signOut() async {
    try {
      await _signOut();
    } catch (_) {
      // Sign-out failure should not block the local session from clearing.
    }
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
