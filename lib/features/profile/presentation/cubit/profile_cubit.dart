import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/profile/domain/entities/profile_entity.dart';
import 'package:fbro/features/profile/domain/usecases/check_username.dart';
import 'package:fbro/features/profile/domain/usecases/get_profile.dart';
import 'package:fbro/features/profile/domain/usecases/update_profile.dart';
import 'package:fbro/features/profile/domain/usecases/upload_cover_image.dart';
import 'package:fbro/features/profile/domain/usecases/upload_profile_image.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;
  final UploadProfileImage _uploadProfileImage;
  final UploadCoverImage _uploadCoverImage;
  final CheckUsername _checkUsername;

  ProfileCubit({
    required this._getProfile,
    required UpdateProfile updateProfile,
    required this._uploadProfileImage,
    required this._uploadCoverImage,
    required this._checkUsername,
  })  : _updateProfile = updateProfile,
        super(const ProfileState.initial());

  /// The currently-known profile, regardless of transient state.
  ProfileEntity? get _current => state.mapOrNull(
        loaded: (s) => s.profile,
        saving: (s) => s.profile,
        saved: (s) => s.profile,
      );

  Future<void> loadProfile(String uid) async {
    emit(const ProfileState.loading());
    try {
      final profile = await _getProfile(uid);
      if (profile != null) {
        emit(ProfileState.loaded(profile));
      } else {
        emit(const ProfileState.error('Profile not found.'));
      }
    } on AuthFailure catch (e) {
      emit(ProfileState.error(e.message));
    } catch (_) {
      emit(const ProfileState.error('Failed to load profile. Please try again.'));
    }
  }

  Future<bool> isUsernameAvailable(String username, String uid) =>
      _checkUsername(username, forUid: uid);

  /// Saves edits. Uploads any picked images first, then writes the document.
  /// Keeps the last-known profile visible throughout so the UI never flickers.
  Future<void> save({
    required String uid,
    String? fullName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? country,
    String? city,
    String? website,
    String? gender,
    DateTime? birthDate,
    File? avatarFile,
    File? coverFile,
  }) async {
    final current = _current;
    if (current == null) return;
    final isSaving = state.maybeMap(saving: (_) => true, orElse: () => false);
    if (isSaving) return; // guard double-submit

    emit(ProfileState.saving(current));
    try {
      // Reject a taken username before doing any writes.
      if (username != null &&
          username.trim().isNotEmpty &&
          username.trim().toLowerCase() != (current.username ?? '')) {
        final free = await _checkUsername(username.trim(), forUid: uid);
        if (!free) {
          emit(const ProfileState.error('That username is already taken.'));
          emit(ProfileState.loaded(current));
          return;
        }
      }

      String? avatarUrl;
      String? coverUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadProfileImage(
          uid,
          avatarFile,
          onProgress: (p) =>
              emit(ProfileState.saving(current, uploadProgress: p)),
        );
      }
      if (coverFile != null) {
        coverUrl = await _uploadCoverImage(
          uid,
          coverFile,
          onProgress: (p) =>
              emit(ProfileState.saving(current, uploadProgress: p)),
        );
      }
      // Final Firestore write — indeterminate (clear the upload progress).
      emit(ProfileState.saving(current));

      final updated = await _updateProfile(
        uid: uid,
        fullName: fullName,
        username: username,
        bio: bio,
        phoneNumber: phoneNumber,
        country: country,
        city: city,
        website: website,
        gender: gender,
        birthDate: birthDate,
        profileImage: avatarUrl,
        coverImage: coverUrl,
      );
      emit(ProfileState.saved(updated));
      emit(ProfileState.loaded(updated));
    } on AuthFailure catch (e) {
      emit(ProfileState.error(e.message));
      emit(ProfileState.loaded(current));
    } catch (_) {
      emit(const ProfileState.error('Failed to save profile. Please try again.'));
      emit(ProfileState.loaded(current));
    }
  }
}
