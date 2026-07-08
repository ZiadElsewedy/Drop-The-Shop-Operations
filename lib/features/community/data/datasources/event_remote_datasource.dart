import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/community/data/models/event_model.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';

/// Firestore + Storage access for Community Hub events (`events/{id}`). Queries
/// are single-filter (collection or `branchId` equality) so they're served by
/// the automatic single-field index — **no composite index needed**; soft-delete
/// filtering and ordering are applied in the repository over the small volume.
///
/// Unordered `.snapshots()` (rather than `orderBy(createdAt)`) is deliberate: a
/// freshly created doc has a null server `createdAt` until the write resolves, so
/// ordering in the query would briefly hide a just-created event from its author.
abstract class EventRemoteDataSource {
  Stream<List<EventEntity>> watchAllEvents();
  Stream<List<EventEntity>> watchBranchEvents(String branchId);
  Stream<EventEntity?> watchEvent(String eventId);
  Future<EventEntity?> getEvent(String eventId);

  String newEventId();
  String newItemId();

  Future<EventEntity> createEvent(EventEntity event);
  Future<void> updateEvent(EventEntity event);
  Future<void> deleteEvent(String eventId);

  Future<String> uploadHeroImage({
    required String eventId,
    required File file,
    AttachmentType type = AttachmentType.image,
    void Function(int transferred, int total)? onProgress,
  });
}

class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  EventRemoteDataSourceImpl(this._firestore, this._storage);

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection(AppConstants.eventsCollection);

  List<EventEntity> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => EventModel.fromMap(d.data(), id: d.id)).toList();

  @override
  String newEventId() => _events.doc().id;

  @override
  String newItemId() => _events.doc().id;

  @override
  Stream<List<EventEntity>> watchAllEvents() =>
      _events.snapshots().map(_mapSnap);

  @override
  Stream<List<EventEntity>> watchBranchEvents(String branchId) => _events
      .where('branchId', isEqualTo: branchId)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<EventEntity?> watchEvent(String eventId) =>
      _events.doc(eventId).snapshots().map((doc) =>
          (!doc.exists || doc.data() == null)
              ? null
              : EventModel.fromMap(doc.data()!, id: doc.id));

  @override
  Future<EventEntity?> getEvent(String eventId) async {
    try {
      final doc = await _events.doc(eventId).get();
      if (!doc.exists || doc.data() == null) return null;
      return EventModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load the event.');
    }
  }

  @override
  Future<EventEntity> createEvent(EventEntity event) async {
    try {
      // Honour a pre-generated id (from [newEventId], so a hero image can already
      // be uploaded under it); otherwise mint a fresh one via the datasource.
      final docRef =
          event.id.isNotEmpty ? _events.doc(event.id) : _events.doc();
      final created =
          event.id.isNotEmpty ? event : EventModel.fromMap(
              EventModel.toCreateMap(event),
              id: docRef.id);
      await docRef.set({
        ...EventModel.toCreateMap(created),
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create the event.');
    }
  }

  @override
  Future<void> updateEvent(EventEntity event) async {
    try {
      await _events.doc(event.id).update({
        ...EventModel.toUpdateMap(event),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the event.');
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      // SOFT delete — stamp `deletedAt`, keep the doc as a record. The hub
      // streams filter deleted events out client-side (no index/migration).
      await _events.doc(eventId).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete the event.');
    }
  }

  static const _uploadTimeout = Duration(seconds: 180);

  @override
  Future<String> uploadHeroImage({
    required String eventId,
    required File file,
    AttachmentType type = AttachmentType.image,
    void Function(int transferred, int total)? onProgress,
  }) async {
    final ext = _extensionFor(file.path);
    final upload = _storage
        .ref('${AppConstants.eventsCollection}/$eventId/hero.$ext')
        .putFile(file, SettableMetadata(contentType: _contentType(ext)));
    final sub = upload.snapshotEvents
        .listen((s) => onProgress?.call(s.bytesTransferred, s.totalBytes));
    try {
      final snapshot = await upload.timeout(
        _uploadTimeout,
        onTimeout: () {
          upload.cancel();
          throw const ServerException(
              'Upload timed out. Check your connection and try again.');
        },
      );
      return await snapshot.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ServerException(
          'Upload timed out. Check your connection and try again.');
    } on FirebaseException catch (e) {
      throw ServerException(_storageError(e));
    } finally {
      await sub.cancel();
    }
  }

  static String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    return 'jpg';
  }

  static String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  static String _storageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'unauthenticated':
        return 'Upload was blocked by Storage permissions (${e.code}). '
            'Firebase Storage rules likely need to be deployed.';
      case 'object-not-found':
      case 'bucket-not-found':
      case 'project-not-found':
        return 'Firebase Storage isn\'t set up for this project (${e.code}). '
            'Enable Storage in the Firebase console, then retry.';
      case 'retry-limit-exceeded':
      case 'canceled':
        return 'Upload failed — check your connection and try again.';
      default:
        return e.message ?? 'Upload failed (${e.code}).';
    }
  }
}
