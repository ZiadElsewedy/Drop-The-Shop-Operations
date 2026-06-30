import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

/// Identifies which authentication action is currently in flight.
///
/// Carried on [AuthState.loading] so the UI can show a spinner ONLY on the
/// button that triggered the request, while disabling the others.
enum AuthAction {
  emailSignIn,
  forgotPassword,
  changePassword,
}

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading(AuthAction action) = _Loading;
  const factory AuthState.authenticated(UserEntity user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.passwordResetSent() = _PasswordResetSent;
  const factory AuthState.passwordChanged() = _PasswordChanged;
  const factory AuthState.error(String message) = _Error;
}
