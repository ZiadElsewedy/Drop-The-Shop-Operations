import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';

class CheckEmailVerified {
  final AuthRepository _repository;
  const CheckEmailVerified(this._repository);

  Future<UserEntity> call() => _repository.reloadUser();
}
