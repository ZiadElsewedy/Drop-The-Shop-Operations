import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbro/core/constants/app_constants.dart';
import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/features/notifications/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<void> create(NotificationModel notification);
  Future<void> createMany(List<NotificationModel> notifications);
  Stream<List<NotificationModel>> watch(String uid);
  Future<void> markRead(String id);
  Future<void> markAllRead(String uid);
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
  Stream<List<NotificationModel>> watch(String uid) {
    // Single-field equality query (automatic index). Ordering is applied
    // client-side in the repository to avoid a composite index (the project's
    // documented approach for filtered streams).
    return _notifications
        .where('recipientUid', isEqualTo: uid)
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
