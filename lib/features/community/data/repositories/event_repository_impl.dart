import 'dart:io';

import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/community/data/datasources/event_remote_datasource.dart';
import 'package:drop/features/community/domain/entities/event_entity.dart';
import 'package:drop/features/community/domain/event_ordering.dart';
import 'package:drop/features/community/domain/repositories/event_repository.dart';

class EventRepositoryImpl implements EventRepository {
  final EventRemoteDataSource _remote;

  EventRepositoryImpl(this._remote);

  /// Drops soft-deleted events and orders them for the hub. The deleted filter is
  /// client-side on purpose: a `where(deletedAt, isNull)` query would exclude
  /// every existing doc missing the field, and the event volume is small.
  List<EventEntity> _ordered(List<EventEntity> events) => sortEventsForHub([
        for (final e in events)
          if (!e.isDeleted) e,
      ]);

  @override
  Stream<List<EventEntity>> watchAllEvents() =>
      _remote.watchAllEvents().map(_ordered);

  @override
  Stream<List<EventEntity>> watchBranchEvents(String branchId) =>
      _remote.watchBranchEvents(branchId).map(_ordered);

  @override
  Stream<EventEntity?> watchEvent(String eventId) => _remote
      .watchEvent(eventId)
      .map((e) => (e == null || e.isDeleted) ? null : e);

  @override
  Future<EventEntity?> getEvent(String eventId) async {
    try {
      final e = await _remote.getEvent(eventId);
      return (e == null || e.isDeleted) ? null : e;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  String newEventId() => _remote.newEventId();

  @override
  String newItemId() => _remote.newItemId();

  @override
  Future<EventEntity> createEvent(EventEntity event) async {
    try {
      return await _remote.createEvent(event);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateEvent(EventEntity event) async {
    try {
      await _remote.updateEvent(event);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _remote.deleteEvent(eventId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<String> uploadHeroImage({
    required String eventId,
    required File file,
    AttachmentType type = AttachmentType.image,
    void Function(int transferred, int total)? onProgress,
  }) async {
    try {
      return await _remote.uploadHeroImage(
        eventId: eventId,
        file: file,
        type: type,
        onProgress: onProgress,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
