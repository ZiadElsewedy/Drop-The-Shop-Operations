import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel?> getProfile(String uid);

  Future<void> updateProfile({
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
    String? profileImage,
    String? coverImage,
  });

  /// Uploads [file] to Storage and returns its download URL.
  /// [onProgress] reports 0.0–1.0 as bytes transfer.
  Future<String> uploadProfileImage(String uid, File file,
      {void Function(double progress)? onProgress});
  Future<String> uploadCoverImage(String uid, File file,
      {void Function(double progress)? onProgress});

  /// True if a username is free (case-insensitive), excluding [forUid].
  Future<bool> isUsernameAvailable(String username, {required String forUid});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ProfileRemoteDataSourceImpl(this._firestore, this._storage);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<ProfileModel?> getProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return ProfileModel.fromMap({'uid': uid, ...doc.data()!});
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to load profile.');
    }
  }

  @override
  Future<void> updateProfile({
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
    String? profileImage,
    String? coverImage,
  }) async {
    try {
      final map = ProfileModel.editMap(
        fullName: fullName,
        username: username,
        bio: bio,
        phoneNumber: phoneNumber,
        country: country,
        city: city,
        website: website,
        gender: gender,
        birthDate: birthDate,
        profileImage: profileImage,
        coverImage: coverImage,
      );
      await _users.doc(uid).set(map, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to update profile.');
    }
  }

  @override
  Future<String> uploadProfileImage(String uid, File file,
          {void Function(double progress)? onProgress}) =>
      _upload('users/$uid/avatar.jpg', file, onProgress);

  @override
  Future<String> uploadCoverImage(String uid, File file,
          {void Function(double progress)? onProgress}) =>
      _upload('users/$uid/cover.jpg', file, onProgress);

  /// Hard ceiling on an upload so a misconfigured/disabled Storage bucket (or a
  /// dropped connection) can never hang the UI indefinitely — it fails cleanly
  /// and the cubit surfaces an error instead of "freezing".
  static const _uploadTimeout = Duration(seconds: 60);

  Future<String> _upload(
    String path,
    File file,
    void Function(double progress)? onProgress,
  ) async {
    try {
      // Fixed path → the upload overwrites the previous image. Firebase issues
      // a fresh download token on overwrite, so the saved URL changes and no
      // stale cache is served.
      final ref = _storage.ref(path);
      final task = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress?.call(s.bytesTransferred / s.totalBytes);
        }
      });
      try {
        final snapshot = await task.timeout(
          _uploadTimeout,
          onTimeout: () {
            task.cancel();
            throw const AuthException(
                'Upload timed out. Check your connection and try again.');
          },
        );
        return await snapshot.ref
            .getDownloadURL()
            .timeout(const Duration(seconds: 20));
      } finally {
        await sub.cancel();
      }
    } on TimeoutException {
      throw const AuthException(
          'Upload timed out. Check your connection and try again.');
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Image upload failed. Please try again.');
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username,
      {required String forUid}) async {
    try {
      final snap = await _users
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return true;
      return snap.docs.first.id == forUid; // their own username is fine
    } on FirebaseException {
      // If the lookup fails (e.g. rules/index), don't block the user.
      return true;
    }
  }
}
