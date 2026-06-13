import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:fbro/features/auth/domain/usecases/register_with_email.dart';
import 'package:fbro/features/auth/domain/usecases/verify_phone_number.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_otp.dart';
import 'package:fbro/features/auth/domain/usecases/sign_out.dart';
import 'package:fbro/features/auth/domain/usecases/save_user.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  final SignInWithEmail _signInWithEmail;
  final RegisterWithEmail _registerWithEmail;
  final VerifyPhoneNumber _verifyPhoneNumber;
  final SignInWithOtp _signInWithOtp;
  final SignOut _signOut;
  final SaveUser _saveUser;

  StreamSubscription? _authSub;

  AuthCubit({
    required this._repository,
    required this._signInWithEmail,
    required this._registerWithEmail,
    required this._verifyPhoneNumber,
    required this._signInWithOtp,
    required this._signOut,
    required this._saveUser,
  }) :
        super(const AuthState.initial()) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _repository.authStateChanges.listen((user) {
      if (user != null) {
        emit(AuthState.authenticated(user));
      } else {
        emit(const AuthState.unauthenticated());
      }
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(const AuthState.loading());
    try {
      final user = await _signInWithEmail(email: email, password: password);
      emit(AuthState.authenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    emit(const AuthState.loading());
    try {
      final user = await _registerWithEmail(email: email, password: password);
      await _saveUser(user);
      emit(AuthState.authenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> verifyPhone(String phoneNumber) async {
    emit(const AuthState.loading());
    await _verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) => emit(AuthState.otpSent(verificationId)),
      onFailed: (error) => emit(AuthState.error(error)),
      onAutoVerified: (user) => emit(AuthState.authenticated(user)),
    );
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

  Future<void> signOut() async {
    await _signOut();
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
