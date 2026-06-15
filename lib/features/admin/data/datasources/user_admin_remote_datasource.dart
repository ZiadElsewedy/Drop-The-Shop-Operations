import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

/// Admin-side access to the `users` collection (reuses the auth [UserModel]).
/// All operations here require an admin caller (enforced by `firestore.rules`).
abstract class UserAdminRemoteDataSource {
  Future<List<UserModel>> getAllUsers();
  Future<List<UserModel>> getUsersByRole(String role);
  Future<List<UserModel>> getPendingUsers();

  /// Admin field update on `users/{uid}` ([data] is merged + `updatedAt` set).
  Future<void> updateUser(String uid, Map<String, dynamic> data);
}

class UserAdminRemoteDataSourceImpl implements UserAdminRemoteDataSource {
  final FirebaseFirestore _firestore;

  UserAdminRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  List<UserModel> _map(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .where((d) => d.data().isNotEmpty)
      .map((d) => UserModel.fromMap(d.data()))
      .toList();

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      return _map(await _users.get());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load users.');
    }
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      return _map(await _users.where('role', isEqualTo: role).get());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load users.');
    }
  }

  @override
  Future<List<UserModel>> getPendingUsers() async {
    try {
      return _map(
          await _users.where('approvalStatus', isEqualTo: 'pending').get());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load pending users.');
    }
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _users.doc(uid).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update user.');
    }
  }
}
