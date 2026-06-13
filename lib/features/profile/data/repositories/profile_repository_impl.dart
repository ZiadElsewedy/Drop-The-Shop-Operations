import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:fbro/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _profileRemote;
  final AuthRemoteDataSource _authRemote;

  ProfileRepositoryImpl(this._profileRemote, this._authRemote);

  @override
  Future<UserEntity?> getProfile(String uid) async {
    final model = await _profileRemote.getProfile(uid);
    return model?.toEntity();
  }

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    await _profileRemote.updateProfile(
      uid: uid,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<void> updateFirebaseDisplayName(String displayName) async {
    try {
      await _authRemote.updateDisplayName(displayName);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> updateFirebasePhotoUrl(String photoUrl) async {
    try {
      await _authRemote.updatePhotoUrl(photoUrl);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<UserEntity> reloadUser() async {
    try {
      final model = await _authRemote.reloadUser();
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
