import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';

/// Contract for the Communications Center (Phase 1). The branch/role access
/// model is enforced server-side by `firestore.rules` (`broadcasts/{id}`): admin
/// sends/reads all branches; an own-branch manager sends to their branch; branch
/// members read their branch's broadcasts plus all-branches ones.
abstract class BroadcastRepository {
  /// Persists a broadcast and returns it with its generated id. The audience /
  /// branch targeting carried on [broadcast] decides who can read it.
  /// [targetUserIds] is the recipient list for a `custom` send; [roleFilter]
  /// (''/`all` = none) restricts a branch/all send to one role.
  Future<BroadcastEntity> sendBroadcast(
    BroadcastEntity broadcast, {
    List<String> targetUserIds,
    String roleFilter,
  });

  /// Realtime stream of broadcasts, newest first.
  ///
  /// - [branchId] `null` → the admin feed: every broadcast, all branches.
  /// - [branchId] set → a branch member's feed: that branch's broadcasts plus
  ///   all-branches broadcasts.
  Stream<List<BroadcastEntity>> watchBroadcasts({String? branchId});

  /// Archives ([archived] true) / unarchives a broadcast.
  Future<void> setArchived(String id, bool archived);

  /// Permanently deletes a broadcast (`broadcasts/{id}`). Allowed only for an
  /// admin, the original sender, or the owning-branch manager (Firestore rules).
  Future<void> delete(String id);
}
