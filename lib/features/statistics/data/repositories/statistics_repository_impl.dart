import 'package:fbro/core/errors/exceptions.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:fbro/features/statistics/data/models/statistics_model.dart';
import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';
import 'package:fbro/features/statistics/domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  final StatisticsRemoteDataSource _remote;

  StatisticsRepositoryImpl(this._remote);

  @override
  Future<StatisticsEntity> adminStats() => _run(_remote.adminStats());

  @override
  Future<StatisticsEntity> managerStats(String branchId) =>
      _run(_remote.managerStats(branchId));

  @override
  Future<StatisticsEntity> employeeStats(String uid) =>
      _run(_remote.employeeStats(uid));

  Future<StatisticsEntity> _run(Future<StatisticsModel> future) async {
    try {
      return (await future).toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
