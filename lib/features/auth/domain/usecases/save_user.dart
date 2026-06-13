import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';

class SaveUser {
  final AuthRepository _repository;
  SaveUser(this._repository);

  Future<void> call(UserEntity user) => _repository.saveUser(user);
}
