import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/case_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/cases/data/models/case_model.dart';
import 'package:drop/features/cases/domain/entities/case_identity.dart';
import 'package:drop/features/cases/domain/entities/case_message.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

abstract class CaseRemoteDataSource {
  Stream<List<CaseModel>> watchAllCases();
  Stream<List<CaseModel>> watchBranchCases(String branchId);
  Future<List<CaseModel>> getMyCases(String uid);
  Future<CaseModel?> getCase(String caseId);
  Stream<CaseModel?> watchCase(String caseId);
  Stream<List<CaseMessage>> watchMessages(String caseId);

  /// A fresh, guaranteed-unique case id — generated up front so opening media
  /// can be uploaded to `cases/{id}/attachments/...` before the doc is written
  /// (so `onCaseCreated` sees the attachments when it builds the opening message).
  String newCaseId();

  /// Writes the case doc + its private `reporter/identity` subdoc atomically.
  /// The opening message is written server-side by `onCaseCreated`.
  Future<CaseModel> createCase(CaseModel newCase, CaseIdentity identity);

  /// Single targeted update — status + timestamps only.
  Future<void> changeStatus(String caseId, CaseStatus to);

  /// Single `add` of one message document (no whole-array rewrite).
  Future<void> sendMessage(String caseId, CaseMessage message);

  Future<CaseIdentity?> revealReporter(String caseId);
  Future<void> deleteCase(String caseId);

  Future<TaskAttachment> uploadAttachment({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  });
}

class CaseRemoteDataSourceImpl implements CaseRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CaseRemoteDataSourceImpl(this._firestore, this._storage);

  /// The private identity subcollection under a case. Named `reporter` (NOT
  /// `private`) so a collectionGroup('reporter') query never collides with
  /// `users/{uid}/private/compensation`.
  static const String _reporterSub = 'reporter';
  static const String _identityDoc = 'identity';
  static const String _messagesSub = 'messages';

  CollectionReference<Map<String, dynamic>> get _cases =>
      _firestore.collection(AppConstants.casesCollection);

  DocumentReference<Map<String, dynamic>> _identityRef(String caseId) =>
      _cases.doc(caseId).collection(_reporterSub).doc(_identityDoc);

  CollectionReference<Map<String, dynamic>> _messagesRef(String caseId) =>
      _cases.doc(caseId).collection(_messagesSub);

  List<CaseModel> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => CaseModel.fromMap(d.data(), id: d.id)).toList();

  @override
  String newCaseId() => _cases.doc().id;

  @override
  Stream<List<CaseModel>> watchAllCases() => _cases
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<List<CaseModel>> watchBranchCases(String branchId) => _cases
      // Two equality filters (branch + manager-visibility) are served by
      // single-field indexes (zigzag merge) — no composite index needed. Order
      // is applied client-side in the repository (per-branch volume is small).
      .where('branchId', isEqualTo: branchId)
      .where('visibleToManager', isEqualTo: true)
      .snapshots()
      .map(_mapSnap);

  @override
  Future<List<CaseModel>> getMyCases(String uid) async {
    developer.log(
      '[CASES] query start: collectionGroup("$_reporterSub")'
      '.where(createdByUserId == $uid)',
      name: 'CASES',
    );
    try {
      // The case doc carries no creator uid (privacy split), so the owner's list
      // comes from the private `reporter` subdocs (collectionGroup), then a
      // per-case fetch. Case volume per filer is small.
      final identitySnap = await _firestore
          .collectionGroup(_reporterSub)
          .where('createdByUserId', isEqualTo: uid)
          .get();
      developer.log(
        '[CASES] collectionGroup ok: ${identitySnap.docs.length} identity doc(s)',
        name: 'CASES',
      );
      final caseIds = <String>{
        for (final d in identitySnap.docs)
          // `reporter` was also used by the retired `reports` collection, and a
          // collection-group query spans both trees. Never reinterpret a legacy
          // report id as a case id.
          if (d.reference.parent.parent != null &&
              d.reference.parent.parent!.parent.id ==
                  AppConstants.casesCollection)
            d.reference.parent.parent!.id,
      };
      if (caseIds.isEmpty) return const [];
      final cases = await Future.wait(caseIds.map((id) async {
        final doc = await _cases.doc(id).get();
        if (!doc.exists || doc.data() == null) return null;
        return CaseModel.fromMap(doc.data()!, id: doc.id);
      }));
      return cases.whereType<CaseModel>().toList();
    } on FirebaseException catch (e, st) {
      developer.log('[CASES] exception code: ${e.code}', name: 'CASES');
      developer.log('[CASES] exception message: ${e.message}', name: 'CASES');
      developer.log('[CASES] exception stackTrace',
          name: 'CASES', error: e, stackTrace: st);
      throw ServerException(
          '[${e.code}] ${e.message ?? 'Failed to load your cases.'}');
    }
  }

  @override
  Future<CaseModel?> getCase(String caseId) async {
    try {
      final doc = await _cases.doc(caseId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CaseModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load case.');
    }
  }

  @override
  Stream<CaseModel?> watchCase(String caseId) =>
      _cases.doc(caseId).snapshots().map((doc) =>
          (!doc.exists || doc.data() == null)
              ? null
              : CaseModel.fromMap(doc.data()!, id: doc.id));

  @override
  Stream<List<CaseMessage>> watchMessages(String caseId) => _messagesRef(caseId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => CaseModel.messageFromMap(d.data(), id: d.id))
          .toList());

  @override
  Future<CaseModel> createCase(CaseModel newCase, CaseIdentity identity) async {
    try {
      // Honor a pre-generated id (from [newCaseId], so opening media already
      // uploaded under it); otherwise mint a fresh one.
      final docRef =
          newCase.id.isNotEmpty ? _cases.doc(newCase.id) : _cases.doc();
      final created =
          newCase.id.isNotEmpty ? newCase : newCase.copyWithId(docRef.id);
      final batch = _firestore.batch();
      batch.set(docRef, {
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Seed ordering before `onCaseCreated` writes the opening message.
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      batch.set(_identityRef(docRef.id), {
        ...CaseModel.identityToMap(identity),
        'caseId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to open case.');
    }
  }

  @override
  Future<void> changeStatus(String caseId, CaseStatus to) async {
    try {
      await _cases.doc(caseId).update({
        'status': to.value,
        'updatedAt': FieldValue.serverTimestamp(),
        // Stamp on close, clear on reopen.
        'closedAt':
            to == CaseStatus.closed ? FieldValue.serverTimestamp() : null,
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the case.');
    }
  }

  @override
  Future<void> sendMessage(String caseId, CaseMessage message) async {
    try {
      await _messagesRef(caseId).add({
        ...CaseModel.messageToMap(message),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to send your message.');
    }
  }

  @override
  Future<CaseIdentity?> revealReporter(String caseId) async {
    try {
      final doc = await _identityRef(caseId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CaseModel.identityFromMap(doc.data()!, caseId: caseId);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to read the reporter.');
    }
  }

  @override
  Future<void> deleteCase(String caseId) async {
    try {
      // The private reporter subdoc + messages are left in place; deleting a
      // case is an admin-only, rare operation and the subdocs are orphaned
      // harmlessly.
      await _cases.doc(caseId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete case.');
    }
  }

  static const _uploadTimeout = Duration(seconds: 180);

  @override
  Future<TaskAttachment> uploadAttachment({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) async {
    final id = _cases.doc().id; // guaranteed-unique 20-char id
    final ext = _extensionFor(file.path, type);
    final upload = _storage
        .ref('${AppConstants.casesCollection}/$caseId/attachments/$id.$ext')
        .putFile(file, SettableMetadata(contentType: _contentType(ext, type)));
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
      final url = await snapshot.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 30));
      return TaskAttachment(
        id: id,
        url: url,
        type: type,
        uploadedAt: DateTime.now(),
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
      );
    } on TimeoutException {
      throw const ServerException(
          'Upload timed out. Check your connection and try again.');
    } on FirebaseException catch (e) {
      throw ServerException(_storageError(e));
    } finally {
      await sub.cancel();
    }
  }

  static String _extensionFor(String path, AttachmentType type) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    return type.isVideo ? 'mp4' : 'jpg';
  }

  static String _contentType(String ext, AttachmentType type) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      default:
        return type.isVideo ? 'video/mp4' : 'image/jpeg';
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
