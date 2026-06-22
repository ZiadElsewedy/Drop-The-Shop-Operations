import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:fbro/features/notifications/data/models/notification_model.dart';
import 'package:fbro/features/notifications/domain/entities/notification_entity.dart';
import 'package:fbro/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remote;

  NotificationRepositoryImpl(this._remote);

  @override
  Future<void> create(NotificationEntity notification) async {
    try {
      await _remote.create(NotificationModel.fromEntity(notification));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> createMany(List<NotificationEntity> notifications) async {
    try {
      await _remote.createMany(
          notifications.map(NotificationModel.fromEntity).toList());
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<NotificationEntity>> watch(String uid) =>
      _remote.watch(uid).map((models) {
        final list = models.map((m) => m.toEntity()).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Future<void> markRead(String id) async {
    try {
      await _remote.markRead(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> markAllRead(String uid) async {
    try {
      await _remote.markAllRead(uid);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
