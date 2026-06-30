import 'dart:io';

import 'package:drop/features/branch/domain/entities/branch_entity.dart';

/// Contract for branch data access (Phase 5). Admin-only writes are enforced
/// server-side in `firestore.rules` (`branches/{branchId}`).
abstract class BranchRepository {
  /// Returns the branches. Cached in memory for a short TTL and shared across
  /// every caller (one repository instance); [forceRefresh] bypasses the cache.
  /// The cache is invalidated automatically after any branch write.
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  });
  Future<BranchEntity> createBranch(BranchEntity branch);
  Future<void> updateBranch(BranchEntity branch);
  Future<void> setBranchActive(String branchId, bool isActive);

  /// Soft delete — marks the branch deleted/inactive rather than removing it.
  Future<void> deleteBranch(String branchId);

  /// Uploads a branch logo ([isLogo] true) or cover image, persists its URL on
  /// the branch doc, and returns the download URL. (§8 Branch Media.)
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  });
}
