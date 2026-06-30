import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/features/schedule/domain/swap_policy.dart';

part 'branch_entity.freezed.dart';

/// A store branch (Phase 5). Branches scope the whole app: managers and
/// employees belong to a branch via `users/{uid}.branchId`, and shifts/tasks
/// carry a `branchId`. Admin-only to create/edit; "delete" is a soft delete
/// ([deletedAt] set), so historical references stay intact.
@freezed
class BranchEntity with _$BranchEntity {
  const BranchEntity._();

  const factory BranchEntity({
    required String id,
    required String name,
    /// Optional area / address label.
    String? location,
    @Default(true) bool isActive,
    /// Branch **logo** (square mark) — Storage `branches/{id}/logo.jpg`. Drives
    /// [BranchAvatar]; null falls back to initials. (§8 Branch Media.)
    String? logoUrl,
    /// Branch **cover** banner — Storage `branches/{id}/cover.jpg`. Null = none.
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    /// Soft-delete marker; null while the branch is live.
    DateTime? deletedAt,
    /// Optional branch-level shift-swap rules (role compatibility, rest hours).
    /// Null = [SwapPolicy.permissive] (any role can swap, no rest rule). Stored
    /// as a nested map under `swapPolicy`.
    SwapPolicy? swapPolicy,
  }) = _BranchEntity;

  bool get isDeleted => deletedAt != null;

  /// The branch's swap rules, or the permissive default when none is set.
  SwapPolicy get effectiveSwapPolicy => swapPolicy ?? SwapPolicy.permissive;
}
