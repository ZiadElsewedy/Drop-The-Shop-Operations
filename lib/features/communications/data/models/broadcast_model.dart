import 'package:fbro/core/enums/broadcast_audience.dart';
import 'package:fbro/core/enums/user_role.dart';
import 'package:fbro/core/extensions/firestore_extensions.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';

/// Firestore (de)serialization for [BroadcastEntity] — collection
/// `broadcasts/{id}`.
///
/// The document is **written by the `sendBroadcast` Cloud Function** (the
/// authoritative send engine); this model is the client's read mapping and the
/// shape of the callable payload. Two `branchId` conventions keep reads
/// index-free and rules-safe:
/// - an **all-branches** broadcast stores the **empty** `''` sentinel, so a
///   branch member's `whereIn: [myBranch, '']` query catches it;
/// - an **individual** (`user`) broadcast stores the [directBranchMarker] — a
///   value no branch feed queries and no real branch equals — so a direct
///   message never surfaces in a branch / all feed (only the recipient + admin
///   read it, via the `targetUserId` rule clause).
class BroadcastModel {
  /// `branchId` marker for an individual (direct-message) broadcast. Never a real
  /// branch id and never `''`, so the branch/all feed queries never return it.
  /// Mirrored by the Cloud Function (`functions/index.js`).
  static const String directBranchMarker = '__direct__';

  final String id;
  final String title;
  final String message;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final BroadcastAudience audience;

  /// `''` for all-branches, a branch id for a branch broadcast, or
  /// [directBranchMarker] for an individual one.
  final String branchId;

  /// The individual recipient for an [BroadcastAudience.user] broadcast; `''`
  /// otherwise.
  final String targetUserId;
  final String category;
  final int? recipientCount;
  final int? deliveredCount;
  final DateTime? createdAt;

  const BroadcastModel({
    required this.id,
    required this.title,
    required this.message,
    required this.senderId,
    required this.senderName,
    this.senderRole = UserRole.manager,
    this.audience = BroadcastAudience.allBranches,
    this.branchId = '',
    this.targetUserId = '',
    this.category = 'general',
    this.recipientCount,
    this.deliveredCount,
    this.createdAt,
  });

  factory BroadcastModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      BroadcastModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        message: map['message'] as String? ?? '',
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        senderRole: UserRole.fromString(map['senderRole'] as String?),
        audience: BroadcastAudience.fromString(map['audience'] as String?),
        branchId: map['branchId'] as String? ?? '',
        targetUserId: map['targetUserId'] as String? ?? '',
        category: map['category'] as String? ?? 'general',
        recipientCount: (map['recipientCount'] as num?)?.toInt(),
        deliveredCount: (map['deliveredCount'] as num?)?.toInt(),
        createdAt: map.date('createdAt'),
      );

  factory BroadcastModel.fromEntity(BroadcastEntity e) => BroadcastModel(
        id: e.id,
        title: e.title,
        message: e.message,
        senderId: e.senderId,
        senderName: e.senderName,
        senderRole: e.senderRole,
        audience: e.audience,
        branchId: _branchIdFor(e),
        targetUserId: e.isDirect ? (e.targetUserId ?? '') : '',
        category: e.category,
        recipientCount: e.recipientCount,
        deliveredCount: e.deliveredCount,
        createdAt: e.createdAt,
      );

  /// The persisted `branchId` for [e]: all-branches → `''`, individual →
  /// [directBranchMarker], branch → the branch id.
  static String _branchIdFor(BroadcastEntity e) {
    switch (e.audience) {
      case BroadcastAudience.allBranches:
        return '';
      case BroadcastAudience.user:
        return directBranchMarker;
      case BroadcastAudience.branch:
        return e.branchId ?? '';
    }
  }

  /// Writable fields. `createdAt` / `recipientCount` are set server-side by the
  /// Cloud Function, so they are excluded here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole.value,
        'audience': audience.value,
        'branchId': branchId,
        'targetUserId': targetUserId,
        'category': category,
      };

  /// The payload sent to the callable `sendBroadcast` Cloud Function. The
  /// function validates permissions, resolves recipients, persists the doc, and
  /// pushes the notification — so only the intent is sent, never a doc write.
  Map<String, dynamic> toCallablePayload() => {
        'title': title,
        'body': message,
        'category': category,
        'audience': audience.value,
        'branchId': audience == BroadcastAudience.branch ? branchId : '',
        'targetUserId': targetUserId,
      };

  BroadcastModel copyWith({
    String? id,
    int? recipientCount,
    int? deliveredCount,
  }) =>
      BroadcastModel(
        id: id ?? this.id,
        title: title,
        message: message,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        audience: audience,
        branchId: branchId,
        targetUserId: targetUserId,
        category: category,
        recipientCount: recipientCount ?? this.recipientCount,
        deliveredCount: deliveredCount ?? this.deliveredCount,
        createdAt: createdAt,
      );

  BroadcastEntity toEntity() => BroadcastEntity(
        id: id,
        title: title,
        message: message,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        audience: audience,
        // The persisted markers ('' for all, directBranchMarker for a DM) map
        // back to a null entity branchId; a real branch id is preserved.
        branchId: (branchId.isEmpty || branchId == directBranchMarker)
            ? null
            : branchId,
        targetUserId: targetUserId.isEmpty ? null : targetUserId,
        category: category,
        recipientCount: recipientCount,
        deliveredCount: deliveredCount,
        createdAt: createdAt,
      );
}
