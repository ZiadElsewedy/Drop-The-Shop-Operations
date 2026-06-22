import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/communications/data/datasources/broadcast_remote_datasource.dart';
import 'package:fbro/features/communications/data/models/broadcast_model.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_entity.dart';
import 'package:fbro/features/communications/domain/repositories/broadcast_repository.dart';

class BroadcastRepositoryImpl implements BroadcastRepository {
  final BroadcastRemoteDataSource _remote;

  BroadcastRepositoryImpl(this._remote);

  @override
  Future<BroadcastEntity> sendBroadcast(BroadcastEntity broadcast) async {
    try {
      final created =
          await _remote.sendBroadcast(BroadcastModel.fromEntity(broadcast));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<BroadcastEntity>> watchBroadcasts({String? branchId}) =>
      _remote
          .watchBroadcasts(branchId: branchId)
          .map((models) => models.map((m) => m.toEntity()).toList());

  @override
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _remote.setArchived(id, archived);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setDeleted(String id, bool deleted) async {
    try {
      await _remote.setDeleted(id, deleted);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
