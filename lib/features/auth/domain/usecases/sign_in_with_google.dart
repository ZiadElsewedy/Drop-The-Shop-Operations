import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';

class SignInWithGoogle {
  final AuthRepository _repository;
  const SignInWithGoogle(this._repository);

  Future<UserEntity> call() => _repository.signInWithGoogle();
}
