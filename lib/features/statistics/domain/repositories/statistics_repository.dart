import 'package:fbro/features/statistics/domain/entities/statistics_entity.dart';

/// Contract for operational statistics (Phase 6). Each method is scoped to a
/// role: admin = global, manager = own branch, employee = own data.
abstract class StatisticsRepository {
  Future<StatisticsEntity> adminStats();
  Future<StatisticsEntity> managerStats(String branchId);
  Future<StatisticsEntity> employeeStats(String uid);
}
