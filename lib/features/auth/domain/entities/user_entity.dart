import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String uid,
    required String email,
    required String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    @Default(false) bool isEmailVerified,
    DateTime? createdAt,
  }) = _UserEntity;
}
