import 'package:fbro/features/branch/domain/entities/branch_entity.dart';

/// Contract for branch data access (Phase 5). Admin-only writes are enforced
/// server-side in `firestore.rules` (`branches/{branchId}`).
abstract class BranchRepository {
  Future<List<BranchEntity>> getBranches({bool includeDeleted = false});
  Future<BranchEntity> createBranch(BranchEntity branch);
  Future<void> updateBranch(BranchEntity branch);
  Future<void> setBranchActive(String branchId, bool isActive);

  /// Soft delete — marks the branch deleted/inactive rather than removing it.
  Future<void> deleteBranch(String branchId);
}
