import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/branch/data/models/branch_model.dart';

abstract class BranchRemoteDataSource {
  /// All branches; soft-deleted ones are excluded unless [includeDeleted].
  Future<List<BranchModel>> getBranches({bool includeDeleted = false});
  Future<BranchModel> createBranch(BranchModel branch);
  Future<void> updateBranch(BranchModel branch);
  Future<void> setBranchActive(String branchId, bool isActive);
  Future<void> softDeleteBranch(String branchId);
}

class BranchRemoteDataSourceImpl implements BranchRemoteDataSource {
  final FirebaseFirestore _firestore;

  BranchRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(AppConstants.branchesCollection);

  @override
  Future<List<BranchModel>> getBranches({bool includeDeleted = false}) async {
    try {
      final snap = await _branches.orderBy('name').get();
      final all =
          snap.docs.map((d) => BranchModel.fromMap(d.data(), id: d.id));
      return (includeDeleted ? all : all.where((b) => b.deletedAt == null))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load branches.');
    }
  }

  @override
  Future<BranchModel> createBranch(BranchModel branch) async {
    try {
      final docRef = _branches.doc();
      final created = branch.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create branch.');
    }
  }

  @override
  Future<void> updateBranch(BranchModel branch) async {
    try {
      await _branches.doc(branch.id).set({
        ...branch.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update branch.');
    }
  }

  @override
  Future<void> setBranchActive(String branchId, bool isActive) async {
    try {
      await _branches.doc(branchId).set({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update branch.');
    }
  }

  @override
  Future<void> softDeleteBranch(String branchId) async {
    try {
      // Soft delete: keep the doc (shifts/tasks/users may reference it) but mark
      // it deleted + inactive so it drops out of the active branch list.
      await _branches.doc(branchId).set({
        'deletedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete branch.');
    }
  }
}
