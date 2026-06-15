import 'package:freezed_annotation/freezed_annotation.dart';

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
    DateTime? createdAt,
    DateTime? updatedAt,
    /// Soft-delete marker; null while the branch is live.
    DateTime? deletedAt,
  }) = _BranchEntity;

  bool get isDeleted => deletedAt != null;
}
