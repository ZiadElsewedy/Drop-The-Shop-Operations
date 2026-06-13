import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';

part 'profile_state.freezed.dart';

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading() = _Loading;
  const factory ProfileState.loaded(UserEntity user) = _Loaded;
  const factory ProfileState.updating() = _Updating;
  const factory ProfileState.updated(UserEntity user) = _Updated;
  const factory ProfileState.error(String message) = _Error;
}
