import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/features/task/domain/entities/task_entity.dart';

part 'task_state.freezed.dart';

@freezed
class TaskState with _$TaskState {
  const factory TaskState.initial() = _Initial;

  /// First load (full-screen spinner).
  const factory TaskState.loading() = _Loading;

  /// Tasks loaded. [busy] marks an in-flight mutation (create/assign/status/…)
  /// while the list stays visible (no flicker).
  const factory TaskState.loaded(
    List<TaskEntity> tasks, {
    @Default(false) bool busy,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] list so the UI never loses its data.
  const factory TaskState.error(String message) = _Error;
}
