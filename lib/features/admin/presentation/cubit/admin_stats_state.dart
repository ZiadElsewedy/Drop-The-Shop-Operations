import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/features/admin/domain/entities/admin_stats.dart';

part 'admin_stats_state.freezed.dart';

@freezed
class AdminStatsState with _$AdminStatsState {
  const factory AdminStatsState.initial() = _Initial;
  const factory AdminStatsState.loading() = _Loading;
  const factory AdminStatsState.loaded(AdminStats stats) = _Loaded;
  const factory AdminStatsState.error(String message) = _Error;
}
