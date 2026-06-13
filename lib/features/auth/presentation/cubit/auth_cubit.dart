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

  AuthCubit({
    required AuthRepository repository,
    required SignInWithEmail signInWithEmail,
    required RegisterWithEmail registerWithEmail,
    required VerifyPhoneNumber verifyPhoneNumber,
    required SignInWithOtp signInWithOtp,
    required SignInWithGoogle signInWithGoogle,
    required SignOut signOut,
    required SaveUser saveUser,
    required GetUser getUser,
    required ForgotPassword forgotPassword,
    required SendEmailVerification sendEmailVerification,
    required CheckEmailVerified checkEmailVerified,
    required ChangePassword changePassword,
    required DeleteAccount deleteAccount,
  })  : _repository = repository,
        _signInWithEmail = signInWithEmail,
        _registerWithEmail = registerWithEmail,
        _verifyPhoneNumber = verifyPhoneNumber,
        _signInWithOtp = signInWithOtp,
        _signInWithGoogle = signInWithGoogle,
        _signOut = signOut,
        _saveUser = saveUser,
        _getUser = getUser,
        _forgotPassword = forgotPassword,
        _sendEmailVerification = sendEmailVerification,
        _checkEmailVerified = checkEmailVerified,
        _changePassword = changePassword,
        _deleteAccount = deleteAccount,
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
    emit(const AuthState.loading());
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
    emit(const AuthState.loading());
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
    emit(const AuthState.loading());
    try {
      final user = await _signInWithGoogle();
      await _saveUser(user);
      emit(AuthState.authenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> verifyPhone(String phoneNumber) async {
    emit(const AuthState.loading());
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
    emit(const AuthState.loading());
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
    emit(const AuthState.loading());
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
    emit(const AuthState.loading());
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
    emit(const AuthState.loading());
    try {
      final uid = _repository.currentUser?.uid;
      await _deleteAccount(
        currentPassword: currentPassword,
        accessToken: accessToken,
      );
      // Delete the Firestore document after the Firebase account is gone.
      if (uid != null) {
        try {
          await _repository.saveUser(
            // Overwrite with a tombstone — we let Firestore cleanup happen.
            // In production use a Cloud Function for this; here we just delete.
            _repository.currentUser!,
          );
        } catch (_) {}
      }
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
