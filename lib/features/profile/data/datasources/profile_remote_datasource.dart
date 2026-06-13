import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel?> getProfile(String uid);
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore _firestore;

  ProfileRemoteDataSourceImpl(this._firestore);

  @override
  Future<UserModel?> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _firestore.collection('users').doc(uid).update(updates);
  }
}
