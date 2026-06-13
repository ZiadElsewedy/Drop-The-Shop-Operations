import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfile {
  final ProfileRepository _repository;
  const UpdateProfile(this._repository);

  Future<UserEntity> call({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    await _repository.updateProfile(
      uid: uid,
      displayName: displayName,
      photoUrl: photoUrl,
    );
    if (displayName != null) {
      await _repository.updateFirebaseDisplayName(displayName);
    }
    if (photoUrl != null) {
      await _repository.updateFirebasePhotoUrl(photoUrl);
    }
    return _repository.reloadUser();
  }
}
