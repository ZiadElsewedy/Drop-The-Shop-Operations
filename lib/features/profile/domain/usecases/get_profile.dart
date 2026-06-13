import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/profile/domain/repositories/profile_repository.dart';

class GetProfile {
  final ProfileRepository _repository;
  const GetProfile(this._repository);

  Future<UserEntity?> call(String uid) => _repository.getProfile(uid);
}
