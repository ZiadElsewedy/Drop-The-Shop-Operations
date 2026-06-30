import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/notifications/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<void> create(NotificationModel notification);
  Future<void> createMany(List<NotificationModel> notifications);

  /// Realtime feed of the most recent [limit] notifications for [uid], newest
  /// first (server-ordered — uses the `recipientUid + createdAt` composite
  /// index). A growing [limit] gives offline-resilient infinite pagination.
  Stream<List<NotificationModel>> watch(String uid, {int limit = 30});
  Future<void> markRead(String id);
  Future<void> markAllRead(String uid);

  /// Permanently deletes one notification (the recipient dismissing it).
  Future<void> delete(String id);

  /// Archives / unarchives one notification (sets / clears `archivedAt`).
  Future<void> setArchived(String id, bool archived);

  /// Pins / unpins one notification (sets / clears `pinnedAt`).
  Future<void> setPinned(String id, bool pinned);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore _firestore;

  NotificationRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(AppConstants.notificationsCollection);

  @override
  Future<void> create(NotificationModel notification) async {
    try {
      final ref = _notifications.doc();
      await ref.set({
        ...notification.toMap(),
        'id': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create notification.');
    }
  }

  @override
  Future<void> createMany(List<NotificationModel> notifications) async {
    if (notifications.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final n in notifications) {
        final ref = _notifications.doc();
        batch.set(ref, {
          ...n.toMap(),
          'id': ref.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create notifications.');
    }
  }

  @override
  Stream<List<NotificationModel>> watch(String uid, {int limit = 30}) {
    // recipientUid equality + createdAt order → the `recipientUid + createdAt`
    // composite index (firestore.indexes.json). A growing [limit] window keeps
    // reads bounded while supporting infinite pagination + realtime updates.
    return _notifications
        .where('recipientUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NotificationModel.fromMap(d.data(), id: d.id)).toList());
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _notifications
          .doc(id)
          .set({'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notification.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _notifications.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete notification.');
    }
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _notifications.doc(id).set(
        {'archivedAt': archived ? FieldValue.serverTimestamp() : null},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notification.');
    }
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    try {
      await _notifications.doc(id).set(
        {'pinnedAt': pinned ? FieldValue.serverTimestamp() : null},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notification.');
    }
  }

  @override
  Future<void> markAllRead(String uid) async {
    try {
      // Single-field query (no composite index); filter unread client-side.
      final snap =
          await _notifications.where('recipientUid', isEqualTo: uid).get();
      final unread =
          snap.docs.where((d) => d.data()['readAt'] == null).toList();
      if (unread.isEmpty) return;
      final batch = _firestore.batch();
      for (final d in unread) {
        batch.set(d.reference, {'readAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notifications.');
    }
  }
}
