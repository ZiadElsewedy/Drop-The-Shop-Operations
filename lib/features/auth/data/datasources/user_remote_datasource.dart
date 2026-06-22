import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/enums/approval_status.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/auth/data/models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser(String uid);
  Future<List<UserModel>> getUsersByBranch(String branchId);

  /// Live stream of a user's document (Phase: stabilization) — used to detect
  /// approval/role changes in real time without polling.
  Stream<UserModel?> watchUser(String uid);
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
      // Seed the profile schema ONCE on first creation, with empty-string
      // defaults. The model's displayName/photoUrl fallback still surfaces a
      // provider-supplied name/avatar for display even though these start "".
      data.addAll(const {
        'fullName': '',
        'username': '',
        'bio': '',
        'profileImage': '',
        'coverImage': '',
      });
      // Seed the role + approval foundation ONCE. These are deliberately NOT
      // part of UserModel.toMap(), so subsequent re-login merges never reset an
      // admin-assigned role/branch or re-pend an approved account.
      //
      // DROP is an internal ops system: a new account is NOT usable yet. It is
      // seeded as a PENDING, INACTIVE employee with no branch and is confined to
      // the Pending Approval screen until a manager/admin approves it (flips
      // approvalStatus → approved, isActive → true, assigns role + branch).
      // The very first admin is bootstrapped out of band (Firebase console).
      data.addAll({
        'role': user.role.value,
        'branchId': user.branchId,
        'isActive': false,
        'assignedShift': user.assignedShift,
        'approvalStatus': ApprovalStatus.pending.value,
      });
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  @override
  Future<List<UserModel>> getUsersByBranch(String branchId) async {
    // Used by managers/admins (assignee/roster pickers) and employees (their
    // branch teammates + manager for the weekly schedule). Security rules let any
    // member read users in their own branch; an admin reads any.
    try {
      final snap = await _firestore
          .collection('users')
          .where('branchId', isEqualTo: branchId)
          .get();
      return snap.docs
          .where((d) => d.data().isNotEmpty)
          .map((d) => UserModel.fromMap(d.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to load branch members.');
    }
  }

  @override
  Stream<UserModel?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => (!doc.exists || doc.data() == null)
              ? null
              : UserModel.fromMap(doc.data()!),
        );
  }
}
