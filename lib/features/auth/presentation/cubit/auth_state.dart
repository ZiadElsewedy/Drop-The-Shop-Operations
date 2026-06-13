import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(UserEntity user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.otpSent(String verificationId) = _OtpSent;
  const factory AuthState.awaitingEmailVerification(UserEntity user) = _AwaitingEmailVerification;
  const factory AuthState.passwordResetSent() = _PasswordResetSent;
  const factory AuthState.passwordChanged() = _PasswordChanged;
  const factory AuthState.error(String message) = _Error;
}
