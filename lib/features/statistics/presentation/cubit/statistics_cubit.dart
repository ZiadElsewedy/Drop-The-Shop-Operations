import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/errors/failures.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';
import 'package:fbro/features/statistics/domain/repositories/statistics_repository.dart';
import 'statistics_state.dart';

/// Loads the role-scoped operational statistics for the dashboards (Phase 6).
/// Admin = global · manager = own branch · employee = own data.
class StatisticsCubit extends Cubit<StatisticsState> {
  final StatisticsRepository _repository;

  StatisticsCubit(this._repository) : super(const StatisticsState.initial());

  Future<void> load(UserEntity user) async {
    emit(const StatisticsState.loading());
    try {
      final stats = user.role.isAdmin
          ? await _repository.adminStats()
          : user.role.isManager
              ? await _repository.managerStats(user.branchId ?? '')
              : await _repository.employeeStats(user.uid);
      emit(StatisticsState.loaded(stats));
    } on Failure catch (e) {
      emit(StatisticsState.error(e.message));
    } catch (_) {
      emit(const StatisticsState.error('Failed to load statistics.'));
    }
  }
}
