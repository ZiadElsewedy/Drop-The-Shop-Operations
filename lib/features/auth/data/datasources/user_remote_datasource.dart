import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser(String uid);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final FirebaseFirestore _firestore;

  UserRemoteDataSourceImpl(this._firestore);

  @override
  Future<void> saveUser(UserModel user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final data = {
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }
}
