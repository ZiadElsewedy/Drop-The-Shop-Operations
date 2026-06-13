import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/profile/domain/usecases/get_profile.dart';
import 'package:fbro/features/profile/domain/usecases/update_profile.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;

  ProfileCubit({
    required GetProfile getProfile,
    required UpdateProfile updateProfile,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        super(const ProfileState.initial());

  Future<void> loadProfile(String uid) async {
    emit(const ProfileState.loading());
    try {
      final user = await _getProfile(uid);
      if (user != null) {
        emit(ProfileState.loaded(user));
      } else {
        emit(const ProfileState.error('Profile not found.'));
      }
    } on AuthFailure catch (e) {
      emit(ProfileState.error(e.message));
    } catch (_) {
      emit(const ProfileState.error('Failed to load profile. Please try again.'));
    }
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    emit(const ProfileState.updating());
    try {
      final updated = await _updateProfile(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      emit(ProfileState.updated(updated));
    } on AuthFailure catch (e) {
      emit(ProfileState.error(e.message));
    } catch (_) {
      emit(const ProfileState.error('Failed to update profile. Please try again.'));
    }
  }
}
