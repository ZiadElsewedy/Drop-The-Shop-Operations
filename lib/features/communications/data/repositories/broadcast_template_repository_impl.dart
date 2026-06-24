import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/communications/data/datasources/broadcast_template_remote_datasource.dart';
import 'package:fbro/features/communications/data/models/broadcast_template_model.dart';
import 'package:fbro/features/communications/domain/entities/broadcast_template_entity.dart';
import 'package:fbro/features/communications/domain/repositories/broadcast_template_repository.dart';

class BroadcastTemplateRepositoryImpl implements BroadcastTemplateRepository {
  final BroadcastTemplateRemoteDataSource _remote;

  BroadcastTemplateRepositoryImpl(this._remote);

  @override
  Future<List<BroadcastTemplateEntity>> getTemplates() async {
    try {
      final models = await _remote.getTemplates();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<BroadcastTemplateEntity> create(BroadcastTemplateEntity template) async {
    try {
      final created =
          await _remote.create(BroadcastTemplateModel.fromEntity(template));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> update(BroadcastTemplateEntity template) async {
    try {
      await _remote.update(BroadcastTemplateModel.fromEntity(template));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setFavorite(String id, bool favorite) async {
    try {
      await _remote.setFavorite(id, favorite);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> incrementUsage(String id) async {
    try {
      await _remote.incrementUsage(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _remote.delete(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
