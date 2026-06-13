import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';

class DeleteAccount {
  final AuthRepository _repository;
  const DeleteAccount(this._repository);

  Future<void> call({
    required String? currentPassword,
    required String? accessToken,
  }) =>
      _repository.deleteAccount(
        currentPassword: currentPassword,
        accessToken: accessToken,
      );
}
