import 'package:fbro/features/auth/domain/entities/user_entity.dart';

abstract class ProfileRepository {
  Future<UserEntity?> getProfile(String uid);
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  });
  Future<void> updateFirebaseDisplayName(String displayName);
  Future<void> updateFirebasePhotoUrl(String photoUrl);
  Future<UserEntity> reloadUser();
}
